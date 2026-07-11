import { rewriteDraft } from "./rewriter.js";
import { sampleDrafts } from "./rules.js";

const input = document.querySelector("#draft-input");
const output = document.querySelector("#rewrite-output");
const score = document.querySelector("#score");
const language = document.querySelector("#language");
const hitCount = document.querySelector("#hit-count");
const issueList = document.querySelector("#issue-list");
const categoryList = document.querySelector("#category-list");
const sampleBar = document.querySelector("#sample-bar");
const rewriteButton = document.querySelector("#rewrite-button");
const copyButton = document.querySelector("#copy-button");
const swapButton = document.querySelector("#swap-button");
const clearButton = document.querySelector("#clear-button");

function init() {
  renderSamples();
  input.value = sampleDrafts[0].text;
  runRewrite();

  input.addEventListener("input", runRewrite);
  rewriteButton.addEventListener("click", runRewrite);
  copyButton.addEventListener("click", copyOutput);
  swapButton.addEventListener("click", swapOutput);
  clearButton.addEventListener("click", clearAll);
}

function renderSamples() {
  sampleBar.innerHTML = "";

  for (const sample of sampleDrafts) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "sample-button";
    button.textContent = sample.label;
    button.addEventListener("click", () => {
      input.value = sample.text;
      runRewrite();
      input.focus();
    });
    sampleBar.append(button);
  }
}

function runRewrite() {
  const result = rewriteDraft(input.value);
  output.value = result.output;
  score.textContent = result.score;
  language.textContent = languageLabel(result.language);
  hitCount.textContent = String(result.hits.length);
  score.dataset.level = scoreLevel(result.score);
  renderIssues(result.hits);
  renderCategories(result.categories);
}

function renderIssues(hits) {
  issueList.innerHTML = "";

  if (!hits.length) {
    issueList.append(emptyState("No obvious slop patterns found."));
    return;
  }

  for (const hit of hits.slice(0, 12)) {
    const item = document.createElement("li");
    item.className = "issue-item";
    item.innerHTML = `
      <div>
        <strong>${escapeHtml(hit.label)}</strong>
        <span>${escapeHtml(hit.tip)}</span>
      </div>
      <code>${escapeHtml(hit.before)}${hit.after ? ` -> ${escapeHtml(hit.after)}` : " -> delete"}</code>
    `;
    issueList.append(item);
  }
}

function renderCategories(categories) {
  categoryList.innerHTML = "";
  const entries = Object.entries(categories);

  if (!entries.length) {
    categoryList.append(emptyState("Clean baseline."));
    return;
  }

  for (const [category, count] of entries) {
    const pill = document.createElement("span");
    pill.className = "category-pill";
    pill.textContent = `${category} ${count}`;
    categoryList.append(pill);
  }
}

async function copyOutput() {
  if (!output.value) return;
  await navigator.clipboard.writeText(output.value);
  copyButton.dataset.copied = "true";
  copyButton.setAttribute("aria-label", "Copied");
  window.setTimeout(() => {
    copyButton.dataset.copied = "false";
    copyButton.setAttribute("aria-label", "Copy rewrite");
  }, 1200);
}

function swapOutput() {
  if (!output.value) return;
  input.value = output.value;
  runRewrite();
  input.focus();
}

function clearAll() {
  input.value = "";
  runRewrite();
  input.focus();
}

function emptyState(text) {
  const item = document.createElement("li");
  item.className = "empty-state";
  item.textContent = text;
  return item;
}

function languageLabel(value) {
  return {
    zh: "Chinese",
    en: "English",
    mixed: "Mixed"
  }[value] ?? "Mixed";
}

function scoreLevel(value) {
  if (value >= 80) return "good";
  if (value >= 55) return "ok";
  return "rough";
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

init();
