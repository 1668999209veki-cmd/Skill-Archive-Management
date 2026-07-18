const fs = require("fs");
const vm = require("vm");

const htmlPath = process.argv[2];
if (!htmlPath) throw new Error("Expected generated HTML path.");
const html = fs.readFileSync(htmlPath, "utf8");
const start = html.indexOf("// STRUCTURED_MATCHER_START");
const end = html.indexOf("// STRUCTURED_MATCHER_END");
if (start < 0 || end < 0 || end <= start) throw new Error("Structured matcher test block not found.");

const context = { console };
context.globalThis = context;
vm.createContext(context);
vm.runInContext(html.slice(start, end), context);
const api = context.__skillMatcherTestApi;
if (!api) throw new Error("Structured matcher test API not exposed.");

function sourceFunction(name, nextName) {
  const startIndex = html.indexOf(`function ${name}(`);
  let endIndex = html.indexOf(`function ${nextName}(`, startIndex);
  if (startIndex < 0 || endIndex < 0 || endIndex <= startIndex) {
    throw new Error(`Unable to extract ${name} from generated page.`);
  }
  const asyncPrefix = html.lastIndexOf("async ", endIndex);
  if (asyncPrefix >= endIndex - 8) endIndex = asyncPrefix;
  return html.slice(startIndex, endIndex);
}

function readJsonScript(id) {
  const match = html.match(new RegExp(`<script type="application/json" id="${id}">([\\s\\S]*?)<\\/script>`));
  return match ? JSON.parse(match[1]) : null;
}

const task = "\u6211\u60f3\u505a\u4e00\u4e2a\u4fe1\u606f\u641c\u7d22\u96f7\u8fbe\uff0c\u9700\u8981\u6293\u53d6\u5c0f\u7ea2\u4e66\u7684\u5185\u5bb9";
const intent = api.parseStructuredIntent(task);
if (!intent.platforms.includes("xiaohongshu") || !intent.actions.includes("scrape")) {
  throw new Error(`Intent extraction failed: ${JSON.stringify(intent)}`);
}
if (intent.matchMode !== "strict_gate" || !intent.professionalActions.includes("scrape")) {
  throw new Error(`Precise task must use strict Gate mode: ${JSON.stringify(intent)}`);
}
const broadIntent = api.parseStructuredIntent("\u5e2e\u6211\u641c\u7d22\u4fe1\u606f\u3001\u505a\u6570\u636e\u5206\u6790");
if (broadIntent.matchMode !== "loose_compatible" || broadIntent.professionalActions.length) {
  throw new Error(`Broad task must use loose compatibility mode: ${JSON.stringify(broadIntent)}`);
}
const voicePetIntent = api.parseStructuredIntent("\u6211\u60f3\u8bbe\u8ba1\u4e00\u4e2a\u684c\u9762\u5ba0\u7269\uff0c\u8ba9\u5b83\u652f\u6301\u8bed\u97f3\u4e92\u52a8");
if (!voicePetIntent.capabilities.includes("voice") || !voicePetIntent.capabilities.includes("interaction")) {
  throw new Error(`Voice interaction must become normalized capabilities: ${JSON.stringify(voicePetIntent)}`);
}
const voiceInteractionIntent = api.parseStructuredIntent("\u8ba9\u5b83\u652f\u6301\u8bed\u97f3\u4e92\u52a8");
const speechMatch = api.matchStructuredCandidate({ name: "speech", description: "Text-to-speech and voice synthesis", category: "Media", triggers: ["speech"] }, voiceInteractionIntent);
if (!speechMatch.gatePassed || !speechMatch.matchedCapabilities.includes("voice")) {
  throw new Error(`Speech must qualify for voice interaction: ${JSON.stringify(speechMatch)}`);
}
const broadMediaVoiceMatch = api.matchStructuredCandidate({ name: "video-db", description: "Audio and video database", category: "Media", triggers: [] }, voiceInteractionIntent);
if (speechMatch.score <= broadMediaVoiceMatch.score) {
  throw new Error(`Dedicated voice Skill must outrank broad media matching: ${JSON.stringify({ speechMatch, broadMediaVoiceMatch })}`);
}
const desktopPetIntent = api.parseStructuredIntent("\u6211\u60f3\u8bbe\u8ba1\u4e00\u4e2a\u684c\u9762\u5ba0\u7269");
const hatchPet = api.matchStructuredCandidate({
  name: "hatch-pet",
  description: "Create, repair, validate, visualize, and animate reusable pet mascots and spritesheets",
  category: "Creative tools",
  triggers: ["hatch-pet"]
}, desktopPetIntent);
if (!hatchPet.gatePassed || !hatchPet.matchedObjects.includes("desktop_pet")) {
  throw new Error(`Desktop pet intent must qualify hatch-pet: ${JSON.stringify(hatchPet)}`);
}
const genericDesignForPet = api.matchStructuredCandidate({ name: "figma", description: "Design interfaces and component systems", category: "Design", triggers: ["figma"] }, desktopPetIntent);
if (genericDesignForPet.gatePassed) {
  throw new Error(`Generic design Skill must not pass a desktop-pet object gate: ${JSON.stringify(genericDesignForPet)}`);
}
const expandedPetCandidates = api.expandLooseRelationshipCandidates(
  [{ key: "hatch-pet", name: "hatch-pet", score: hatchPet.score, baseScore: hatchPet.score, confidence: hatchPet.confidence, reasons: [], record: { name: "hatch-pet" } }],
  [{ name: "hatch-pet" }, { name: "imagegen", description: "Generate pet sprites and visual assets" }],
  [{ source: "hatch-pet", target: "imagegen", targetKind: "skill", type: "mentions" }],
  { globalIntent: desktopPetIntent, subtasks: [{ id: 0, text: desktopPetIntent.text, intent: desktopPetIntent }] }
);
if (!expandedPetCandidates.some(candidate => candidate.key === "imagegen" && candidate.relationshipSupport)) {
  throw new Error(`Loose desktop-pet matching must include related support skills: ${JSON.stringify(expandedPetCandidates)}`);
}
const noSecondHop = api.expandLooseRelationshipCandidates(
  [{ key: "hatch-pet", name: "hatch-pet", score: 20, baseScore: 20, confidence: .8, reasons: [], record: { name: "hatch-pet" } }],
  [{ name: "hatch-pet" }, { name: "imagegen", description: "pet image assets" }, { name: "brainstorming", description: "ideas" }],
  [
    { source: "hatch-pet", target: "imagegen", targetKind: "skill", type: "mentions" },
    { source: "imagegen", target: "brainstorming", targetKind: "skill", type: "mentions" }
  ],
  { globalIntent: desktopPetIntent, subtasks: [{ id: 0, text: desktopPetIntent.text, intent: desktopPetIntent }] }
);
if (noSecondHop.some(candidate => candidate.key === "brainstorming")) {
  throw new Error(`Relationship expansion must not add second-hop candidates: ${JSON.stringify(noSecondHop)}`);
}
const generatedRecords = readJsonScript("skillData") || [];
const generatedRelationships = (readJsonScript("relationshipData") || {}).relationships || [];
const generatedHatchPet = generatedRecords.find(record => record.name === "hatch-pet");
if (generatedHatchPet) {
  const generatedHatchMatch = api.matchStructuredCandidate(generatedHatchPet, desktopPetIntent);
  if (!generatedHatchMatch.gatePassed) throw new Error(`Generated hatch-pet record must match desktop pet intent: ${JSON.stringify(generatedHatchMatch)}`);
  const generatedExpanded = api.expandLooseRelationshipCandidates(
    [{ key: "hatch-pet", name: "hatch-pet", score: generatedHatchMatch.score, baseScore: generatedHatchMatch.score, confidence: generatedHatchMatch.confidence, reasons: [], record: generatedHatchPet }],
    generatedRecords,
    generatedRelationships,
    { globalIntent: desktopPetIntent, subtasks: [{ id: 0, text: desktopPetIntent.text, intent: desktopPetIntent }] }
  );
  if (!generatedExpanded.some(candidate => candidate.relationshipSupport)) {
    throw new Error("Generated hatch-pet relationships must add at least one supporting Skill.");
  }
}
const extendedAliases = api.parseStructuredIntent("\u4ece\u5c0f\u7ea2\u4e66\u5e73\u53f0\u62c9\u53d6\u6570\u636e\uff0c\u6279\u91cf\u5904\u7406\u5e76\u5b9a\u65f6\u4efb\u52a1\u6267\u884c");
if (!extendedAliases.platforms.includes("xiaohongshu") || !extendedAliases.actions.includes("scrape") || !extendedAliases.constraints.includes("batch") || !extendedAliases.constraints.includes("scheduled")) {
  throw new Error(`Extended alias normalization failed: ${JSON.stringify(extendedAliases)}`);
}

const fixtures = [
  { name: "lark-vc", description: "\u98de\u4e66\u89c6\u9891\u4f1a\u8bae\uff0c\u641c\u7d22\u5386\u53f2\u4f1a\u8bae\u548c\u5185\u5bb9", category: "Lark / \u98de\u4e66", triggers: ["lark-vc"] },
  { name: "lark-minutes", description: "\u98de\u4e66\u5999\u8bb0\u548c\u4f1a\u8bae\u7eaa\u8981", category: "Lark / \u98de\u4e66", triggers: ["lark-minutes"] },
  { name: "lark-contact", description: "\u98de\u4e66\u8054\u7cfb\u4eba\u4fe1\u606f\u641c\u7d22", category: "Lark / \u98de\u4e66", triggers: ["lark-contact"] },
  { name: "xhs-note-creator", description: "Create Xiaohongshu Redbook note content", category: "Content", triggers: ["xhs", "redbook"] },
  { name: "xhs-note-scraper", description: "Scrape and collect Xiaohongshu XHS notes", category: "Data collection", triggers: ["xhs", "scrape"] }
];

const results = fixtures.map(record => api.matchStructuredCandidate(record, intent));
for (const name of ["lark-vc", "lark-minutes", "lark-contact", "xhs-note-creator"]) {
  const result = results.find(item => item.name === name);
  if (!result || result.gatePassed) throw new Error(`Expected Gate rejection: ${name} ${JSON.stringify(result)}`);
}
const scraper = results.find(item => item.name === "xhs-note-scraper");
if (!scraper || !scraper.gatePassed || !scraper.matchedPlatforms.includes("xiaohongshu") || !scraper.matchedActions.includes("scrape")) {
  throw new Error(`Expected qualified XHS scraper: ${JSON.stringify(scraper)}`);
}
const looseAnalyzer = api.matchStructuredCandidate({ name: "data-analysis", description: "Analyze metrics and statistics", category: "Analytics", triggers: ["analyze"] }, broadIntent);
const looseLark = api.matchStructuredCandidate(fixtures[0], broadIntent);
if (!looseAnalyzer.gatePassed || looseLark.gatePassed) {
  throw new Error(`Loose compatibility matching failed: ${JSON.stringify({ looseAnalyzer, looseLark })}`);
}

const githubQuery = api.githubSearchKeywordForIntent(intent);
if (!/xiaohongshu|xhs|redbook/i.test(githubQuery) || !/scrape|crawler|collector/i.test(githubQuery)) {
  throw new Error(`Github query lacks core capability: ${githubQuery}`);
}
if (/\b(?:information|content|tool|skill)\b/i.test(githubQuery.replace(/codex skill SKILL\.md/gi, ""))) {
  throw new Error(`Github query contains generic search terms: ${githubQuery}`);
}

vm.runInContext(`function cleanReportLine(value) { return String(value || "").replace(/\\s+/g, " ").trim(); }\n${sourceFunction("githubSearchQueriesForGap", "githubSearchUrl")}\nglobalThis.__githubSearchQueriesForGap = githubSearchQueriesForGap;`, context);
const notionQueries = context.__githubSearchQueriesForGap("我需要抓取 Notion 的公开页面，并整理成 CSV 数据报表");
if (!notionQueries.includes("notion skill")) {
  throw new Error(`Platform Skill discovery query is required for Notion tasks: ${JSON.stringify(notionQueries)}`);
}
const notionScrapeIntent = api.parseStructuredIntent("我需要抓取 Notion 的公开页面，并整理成 CSV 数据报表");
const autocliSkill = api.matchStructuredCandidate({
  name: "autocli-skill",
  description: "Give an AI Agent access to Notion and other web platforms, fetching real-time data through a reusable Skill.",
  category: "Agent skill",
  triggers: ["autocli-skill"]
}, notionScrapeIntent);
if (!autocliSkill.gatePassed || !autocliSkill.matchedPlatforms.includes("notion") || !autocliSkill.matchedActions.includes("scrape")) {
  throw new Error(`A structured Notion retrieval Skill must survive the useful-candidate filter: ${JSON.stringify(autocliSkill)}`);
}

vm.runInContext(`${sourceFunction("candidateFullyCoversSubtask", "uncoveredSubtasks")}${sourceFunction("uncoveredSubtasks", "compactSkillId")}\nglobalThis.__uncoveredSubtasks = uncoveredSubtasks;`, context);
const falseLocalCoverage = context.__uncoveredSubtasks({
  subtasks: ["我需要抓取 Notion 的公开页面，并整理成 CSV 数据报表"],
  structuredPlan: {
    subtasks: [{ id: 0, text: "我需要抓取 Notion 的公开页面，并整理成 CSV 数据报表", intent: notionScrapeIntent }]
  }
}, [{
  coveredSubtasks: ["我需要抓取 Notion 的公开页面，并整理成 CSV 数据报表"],
  coveredSubtaskIds: [0],
  matchedPlatforms: [],
  matchedActions: [],
  matchedCapabilities: []
}]);
if (!falseLocalCoverage.length) {
  throw new Error("A local card without the required platform/action evidence must not suppress Github fallback.");
}

vm.runInContext(`${sourceFunction("filterGithubResultsForIntent", "verifyGithubSkillStructure")}\nglobalThis.__filterGithubResultsForIntent = filterGithubResultsForIntent;`, context);
const filteredAutocli = context.__filterGithubResultsForIntent({ structuredIntent: notionScrapeIntent }, [{
  name: "nashsu/autocli-skill",
  url: "https://github.com/nashsu/autocli-skill",
  description: "Give an AI Agent access to Notion and other web platforms, fetching real-time data through a reusable Skill.",
  topics: ["skill", "agent"],
  stars: 896
}]);
if (filteredAutocli.length !== 1) {
  throw new Error(`A GitHub result with matching Notion and retrieval evidence must render as a candidate: ${JSON.stringify(filteredAutocli)}`);
}

vm.runInContext(`${sourceFunction("recommendationGroups", "developmentOrderSuggestion")}\nglobalThis.__recommendationGroups = recommendationGroups;`, context);
const adviceGroups = context.__recommendationGroups([
  { key: "transcribe", coveredSubtaskIds: [0], coveredSubtasks: ["支持语音对话"] },
  { key: "liquid-glass-design", coveredSubtaskIds: [0, 1], coveredSubtasks: ["支持语音对话", "实现界面交互"] }
]);
if (adviceGroups.length !== 1) {
  throw new Error(`Skills that share the same primary task must render as one development-advice group: ${JSON.stringify(adviceGroups)}`);
}

const bodyOnly = { name: "fixture", description: "unrelated utility", category: "Misc", triggers: [], searchTerms: ["note"] };
const notebook = { name: "notebook-helper", description: "notebook helper", category: "Misc", triggers: [] };
const exact = { name: "note-taker", description: "meeting note tool", category: "Docs", triggers: ["note"] };
if (api.archiveSearchMatches(bodyOnly, "note")) throw new Error("Body-only search term must not match.");
if (!api.archiveSearchMatches(notebook, "note")) throw new Error("Latin substring should match notebook.");
if (!api.archiveSearchMatches(exact, "note")) throw new Error("Exact Latin token should match.");

console.log("structured matcher regression cases passed");
