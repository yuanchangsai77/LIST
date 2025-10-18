const DEFAULT_SOURCE_SNIPPET = `import asyncio

async def run(log):
    await log("Hello, 灵体!")
`;

const state = {
  availableCards: [],
  queue: [],
  output: [],
  mode: "idle",
  isRunning: false,
};

const editorState = {
  visible: false,
  editingCardId: null,
  dirty: false,
};

const dom = {
  cardsList: document.getElementById("cardsList"),
  queueList: document.getElementById("queueList"),
  queueDropZone: document.getElementById("queueDropZone"),
  outputLog: document.getElementById("outputLog"),
  modeDisplay: document.getElementById("modeDisplay"),
  runningIndicator: document.getElementById("runningIndicator"),
  runOnceBtn: document.getElementById("runOnceBtn"),
  runAllBtn: document.getElementById("runAllBtn"),
  runEndlessBtn: document.getElementById("runEndlessBtn"),
  stopBtn: document.getElementById("stopBtn"),
  clearOutputBtn: document.getElementById("clearOutputBtn"),
  editorPanel: document.getElementById("cardEditor"),
  editorToggle: document.getElementById("toggleEditorBtn"),
  editorClose: document.getElementById("cardEditorClose"),
  cardEditorList: document.getElementById("cardEditorList"),
  cardEditorForm: document.getElementById("cardEditorForm"),
  cardEditorTitle: document.getElementById("cardEditorTitle"),
  cardEditorName: document.getElementById("cardEditorName"),
  cardEditorDescription: document.getElementById("cardEditorDescription"),
  cardEditorSource: document.getElementById("cardEditorSource"),
  cardEditorSubmit: document.getElementById("cardEditorSubmit"),
  cardEditorReset: document.getElementById("cardEditorReset"),
};

const templates = {
  card: document.getElementById("cardTemplate"),
  queueItem: document.getElementById("queueItemTemplate"),
  logRow: document.getElementById("logRowTemplate"),
  editorRow: document.getElementById("cardEditorRowTemplate"),
};

function cloneTemplate(template) {
  return template.content.firstElementChild.cloneNode(true);
}

function findCard(cardId) {
  return state.availableCards.find((card) => card.id === cardId);
}

async function fetchState() {
  try {
    const response = await fetch("/api/state", { cache: "no-store" });
    if (!response.ok) throw new Error("无法获取状态");
    const data = await response.json();
    state.availableCards = data.available_cards ?? [];
    state.queue = data.queue ?? [];
    state.output = data.output ?? [];
    state.mode = data.mode ?? "idle";
    state.isRunning = Boolean(data.is_running);
    render();
  } catch (error) {
    console.error(error);
  }
}

async function addToQueue(cardId) {
  try {
    const response = await fetch("/api/queue", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ card_id: cardId }),
    });
    if (!response.ok) throw new Error("无法添加卡片到运行列表");
    await fetchState();
  } catch (error) {
    console.error(error);
    alert(error.message);
  }
}

async function removeFromQueue(queueId) {
  try {
    const response = await fetch(`/api/queue/${queueId}`, { method: "DELETE" });
    if (!response.ok) throw new Error("无法移除队列项");
    await fetchState();
  } catch (error) {
    console.error(error);
    alert(error.message);
  }
}

async function createCard(payload) {
  const response = await fetch("/api/cards", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(await extractError(response, "创建卡片失败"));
  }
  return response.json();
}

async function updateCard(cardId, payload) {
  const response = await fetch(`/api/cards/${cardId}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(await extractError(response, "更新卡片失败"));
  }
  return response.json();
}

async function deleteCard(cardId) {
  const response = await fetch(`/api/cards/${cardId}`, { method: "DELETE" });
  if (!response.ok) {
    throw new Error(await extractError(response, "删除卡片失败"));
  }
}

async function extractError(response, fallback) {
  try {
    const payload = await response.json();
    if (payload?.detail) return payload.detail;
  } catch (error) {
    console.error("Failed to read error payload", error);
  }
  return fallback;
}

function render() {
  renderCards();
  renderQueue();
  renderOutput();
  renderStatus();
  renderCardEditor();
}

function renderCards() {
  dom.cardsList.replaceChildren();
  if (!state.availableCards.length) {
    const empty = document.createElement("p");
    empty.textContent = "当前没有可用的灵体卡片。";
    dom.cardsList.appendChild(empty);
    return;
  }
  state.availableCards.forEach((card) => {
    const node = cloneTemplate(templates.card);
    node.dataset.cardId = card.id;
    node.querySelector("[data-card-name]").textContent = card.name;
    node.querySelector("[data-card-description]").textContent = card.description;
    node.addEventListener("dragstart", (event) => onCardDragStart(event, card));
    node.addEventListener("dblclick", () => toggleCardEnlarged(node));
    const addButton = node.querySelector("[data-add-button]");
    addButton.addEventListener("click", () => addToQueue(card.id));
    dom.cardsList.appendChild(node);
  });
}

function renderCardEditorList() {
  if (!dom.cardEditorList || !templates.editorRow) return;
  dom.cardEditorList.replaceChildren();
  if (!state.availableCards.length) {
    const empty = document.createElement("p");
    empty.className = "editor-empty";
    empty.textContent = "暂未定义任何卡片。";
    dom.cardEditorList.appendChild(empty);
    return;
  }
  state.availableCards.forEach((card) => {
    const row = cloneTemplate(templates.editorRow);
    row.dataset.cardId = card.id;
    row.querySelector("[data-editor-name]").textContent = card.name;
    row.querySelector("[data-editor-id]").textContent = card.id;
    row.querySelector("[data-editor-description]").textContent = card.description || "（无描述）";
    row.querySelector("[data-editor-edit]").addEventListener("click", () => {
      toggleEditor(true);
      loadCardIntoForm(card.id);
    });
    row.querySelector("[data-editor-delete]").addEventListener("click", async () => {
      if (!confirm(`确认删除卡片「${card.name}」？`)) return;
      try {
        await deleteCard(card.id);
        if (editorState.editingCardId === card.id) {
          resetCardForm();
        }
        await fetchState();
      } catch (error) {
        console.error(error);
        alert(error.message);
      }
    });
    dom.cardEditorList.appendChild(row);
  });
}

function renderCardEditor() {
  if (!dom.editorPanel) return;
  renderCardEditorList();
  dom.editorPanel.hidden = !editorState.visible;
  if (!editorState.visible) {
    return;
  }
  if (editorState.editingCardId) {
    const card = findCard(editorState.editingCardId);
    if (!card) {
      resetCardForm();
      return;
    }
    dom.cardEditorTitle.textContent = `编辑：${card.name}`;
    dom.cardEditorSubmit.textContent = "保存修改";
    if (!editorState.dirty) {
      dom.cardEditorName.value = card.name ?? "";
      dom.cardEditorDescription.value = card.description ?? "";
      dom.cardEditorSource.value = card.source ?? "";
    }
  } else {
    dom.cardEditorTitle.textContent = "新建灵体卡片";
    dom.cardEditorSubmit.textContent = "创建卡片";
    if (!editorState.dirty && !dom.cardEditorSource.value) {
      dom.cardEditorSource.value = DEFAULT_SOURCE_SNIPPET.trim();
    }
  }
}

function renderQueue() {
  dom.queueList.replaceChildren();
  if (!state.queue.length) {
    const placeholder = document.createElement("div");
    placeholder.className = "queue-placeholder";
    placeholder.textContent = "拖入灵体卡片以建立运行序列。";
    dom.queueList.appendChild(placeholder);
    return;
  }

  state.queue.forEach((item, index) => {
    const node = cloneTemplate(templates.queueItem);
    node.dataset.queueId = item.queue_id;
    node.querySelector("[data-order]").textContent = `#${index + 1}`;
    node.querySelector("[data-name]").textContent = item.card_name;
    const statusLabel = node.querySelector("[data-status]");
    statusLabel.dataset.state = item.status;
    statusLabel.textContent = formatStatus(item.status);
    node.querySelector("[data-remove]").addEventListener("click", () => removeFromQueue(item.queue_id));
    dom.queueList.appendChild(node);
  });
}

function renderOutput() {
  dom.outputLog.replaceChildren();
  if (!state.output.length) {
    const placeholder = document.createElement("div");
    placeholder.className = "log-row";
    const meta = document.createElement("span");
    meta.className = "log-meta";
    meta.textContent = "暂无输出";
    placeholder.appendChild(meta);
    dom.outputLog.appendChild(placeholder);
    return;
  }

  state.output.forEach((entry) => {
    const node = cloneTemplate(templates.logRow);
    const timestamp = new Date(entry.timestamp).toLocaleTimeString();
    node.querySelector("[data-meta]").textContent = `[${timestamp}] ${entry.card_name} (#${entry.queue_id})`;
    node.querySelector("[data-message]").textContent = entry.message;
    dom.outputLog.appendChild(node);
  });
  dom.outputLog.scrollTop = dom.outputLog.scrollHeight;
}

function renderStatus() {
  dom.modeDisplay.textContent = state.mode;
  dom.runningIndicator.dataset.active = state.isRunning ? "true" : "false";
}

function formatStatus(status) {
  switch (status) {
    case "pending":
      return "待运行";
    case "running":
      return "运行中";
    case "completed":
      return "已完成";
    default:
      return status;
  }
}

function onCardDragStart(event, card) {
  event.dataTransfer.effectAllowed = "copy";
  event.dataTransfer.setData("application/card-id", card.id);
  event.dataTransfer.setData("text/plain", card.name);
}

function toggleCardEnlarged(node) {
  document.querySelectorAll(".card--enlarged").forEach((element) => {
    if (element !== node) element.classList.remove("card--enlarged");
  });
  node.classList.toggle("card--enlarged");
}

function setupDragAndDrop() {
  const dropZone = dom.queueDropZone;

  dropZone.addEventListener("dragover", (event) => {
    if (event.dataTransfer.types.includes("application/card-id")) {
      event.preventDefault();
      dropZone.classList.add("drop-zone--active");
    }
  });

  dropZone.addEventListener("dragleave", () => {
    dropZone.classList.remove("drop-zone--active");
  });

  dropZone.addEventListener("drop", async (event) => {
    event.preventDefault();
    dropZone.classList.remove("drop-zone--active");
    const cardId = event.dataTransfer.getData("application/card-id");
    if (cardId) {
      await addToQueue(cardId);
    }
  });
}

function setupControls() {
  dom.runOnceBtn.addEventListener("click", () => triggerControl("run-once"));
  dom.runAllBtn.addEventListener("click", () => triggerControl("run-all"));
  dom.runEndlessBtn.addEventListener("click", () => triggerControl("run-endless"));
  dom.stopBtn.addEventListener("click", () => triggerControl("stop"));
  dom.clearOutputBtn.addEventListener("click", () => triggerControl("clear-output"));
}

function setupEditorControls() {
  if (!dom.editorToggle || !dom.cardEditorForm) return;
  dom.editorToggle.addEventListener("click", () => toggleEditor(!editorState.visible));
  dom.editorClose.addEventListener("click", () => toggleEditor(false));
  dom.cardEditorReset.addEventListener("click", () => resetCardForm());
  dom.cardEditorForm.addEventListener("submit", handleCardFormSubmit);
  dom.cardEditorForm.addEventListener("input", () => {
    editorState.dirty = true;
  });
}

async function triggerControl(action) {
  try {
    const response = await fetch(`/api/control/${action}`, { method: "POST" });
    if (!response.ok) {
      throw new Error("操作失败");
    }
    await fetchState();
  } catch (error) {
    console.error(error);
    alert(error.message);
  }
}

function toggleEditor(visible) {
  if (!dom.editorPanel) return;
  const wasVisible = editorState.visible;
  editorState.visible = visible;
  dom.editorPanel.hidden = !visible;
  if (visible && !wasVisible) {
    resetCardForm();
  }
  if (!visible) {
    editorState.editingCardId = null;
    editorState.dirty = false;
  }
}

function resetCardForm() {
  if (!dom.cardEditorForm) return;
  editorState.editingCardId = null;
  editorState.dirty = false;
  dom.cardEditorTitle.textContent = "新建灵体卡片";
  dom.cardEditorSubmit.textContent = "创建卡片";
  dom.cardEditorName.value = "";
  dom.cardEditorDescription.value = "";
  dom.cardEditorSource.value = DEFAULT_SOURCE_SNIPPET.trim();
}

function loadCardIntoForm(cardId) {
  const card = findCard(cardId);
  if (!card) {
    alert("找不到要编辑的卡片。");
    return;
  }
  editorState.editingCardId = cardId;
  editorState.dirty = false;
  dom.cardEditorTitle.textContent = `编辑：${card.name}`;
  dom.cardEditorSubmit.textContent = "保存修改";
  dom.cardEditorName.value = card.name ?? "";
  dom.cardEditorDescription.value = card.description ?? "";
  dom.cardEditorSource.value = card.source ?? "";
}

async function handleCardFormSubmit(event) {
  event.preventDefault();
  const payload = {
    name: dom.cardEditorName.value.trim(),
    description: dom.cardEditorDescription.value,
    source: dom.cardEditorSource.value,
  };
  try {
    if (editorState.editingCardId) {
      const cardId = editorState.editingCardId;
      await updateCard(cardId, payload);
      editorState.dirty = false;
      await fetchState();
      loadCardIntoForm(cardId);
    } else {
      const result = await createCard(payload);
      editorState.dirty = false;
      await fetchState();
      if (result?.id) {
        loadCardIntoForm(result.id);
      } else {
        resetCardForm();
      }
    }
  } catch (error) {
    console.error(error);
    alert(error.message);
  }
}

setupDragAndDrop();
setupControls();
setupEditorControls();
fetchState();
setInterval(fetchState, 1200);
