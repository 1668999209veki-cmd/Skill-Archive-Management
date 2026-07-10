import assert from "node:assert/strict";
import { detectLanguage, rewriteDraft } from "../src/rewriter.js";
import { sampleDrafts } from "../src/rules.js";

const zh = rewriteDraft("在当今快速发展的数字时代，企业需要不断地赋能团队。值得注意的是，这不仅仅是工具升级，更是组织能力的全面跃迁。");
assert.equal(detectLanguage("这是中文草稿"), "zh");
assert.ok(zh.output.includes("帮助团队"));
assert.ok(zh.output.includes("也是在提升组织能力"));
assert.ok(!zh.output.includes("在当今快速发展的数字时代"));
assert.ok(zh.hits.length >= 4);
assert.ok(zh.score < 70);

const en = rewriteDraft(sampleDrafts.find((sample) => sample.id === "en-product").text);
assert.equal(detectLanguage("This is an English draft."), "en");
assert.ok(!/fast-paced digital landscape/i.test(en.output));
assert.ok(/use solid solutions/i.test(en.output));
assert.ok(/It is also a real change/i.test(en.output));
assert.ok(/looks at how to use the platform\./i.test(en.output));
assert.ok(en.hits.length >= 4);
assert.ok(en.score < 70);

const clean = rewriteDraft("我们今天先把问题说清楚，再决定下一步怎么做。");
assert.equal(clean.hits.length, 0);
assert.equal(clean.score, 100);

const genericCopy = rewriteDraft("这是一款面向团队协作的工具，可以帮助用户管理任务、记录进展并提高工作效率。");
assert.notEqual(genericCopy.output, "这是一款面向团队协作的工具，可以帮助用户管理任务、记录进展并提高工作效率。");
assert.ok(genericCopy.output.includes("这款工具"));
assert.ok(genericCopy.output.includes("能帮用户"));
assert.ok(genericCopy.hits.some((hit) => hit.id === "zh-general-polish"));

const userDraft = rewriteDraft("OpenAI Codex是OpenAI開發的人工智慧代碼生成模型，主要用於根據自然語言提示生成、補全和修改程序代碼。OpenAI於2021年8月發布Codex，並通過API私人測試版提供訪問。");
assert.notEqual(userDraft.output, "OpenAI Codex是OpenAI開發的人工智慧代碼生成模型，主要用於根據自然語言提示生成、補全和修改程序代碼。OpenAI於2021年8月發布Codex，並通過API私人測試版提供訪問。");
assert.ok(userDraft.hits.length > 0);
assert.ok(userDraft.output.includes("开放试用"));
assert.ok(userDraft.output.includes("补全"));
assert.ok(userDraft.output.includes("发布了 Codex"));
assert.ok(userDraft.output.includes("OpenAI 做的 AI 编程模型"));
assert.ok(userDraft.output.includes("可以按自然语言提示"));
assert.ok(!userDraft.output.includes("=>"));
assert.ok(!userDraft.output.includes("(match)"));

console.log("rewriter tests passed");
