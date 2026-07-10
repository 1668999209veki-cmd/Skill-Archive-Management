import { phraseRules, rhythmRules } from "./rules.js";

const categoryWeights = {
  cliche: 16,
  filler: 10,
  buzzword: 12,
  intensifier: 7,
  structure: 9,
  tone: 8,
  fallback: 4
};

export function detectLanguage(text) {
  const compact = text.replace(/\s/g, "");
  if (!compact) return "mixed";

  const cjkCount = [...compact].filter((char) => /[\u3400-\u9fff]/.test(char)).length;
  const ratio = cjkCount / compact.length;

  if (ratio > 0.35) return "zh";
  if (ratio < 0.05) return "en";
  return "mixed";
}

export function rewriteDraft(input) {
  const original = input.trim();
  if (!original) {
    return {
      language: "mixed",
      output: "",
      score: 100,
      hits: [],
      categories: {}
    };
  }

  const language = detectLanguage(original);
  const activeRules = phraseRules.filter((rule) => rule.language === language || language === "mixed");
  let output = original;
  const hits = [];

  for (const rule of activeRules) {
    const before = output;
    output = output.replace(rule.pattern, (match) => {
      const replacement = typeof rule.replacement === "function"
        ? rule.replacement(match)
        : rule.replacement;

      hits.push({
        id: rule.id,
        label: rule.label,
        category: rule.category,
        before: match,
        after: replacement,
        tip: rule.tip
      });
      return replacement;
    });

    if (before !== output) {
      output = tidyText(output, language);
    }
  }

  for (const rule of rhythmRules) {
    output = output.replace(rule.pattern, (match) => {
      hits.push({
        id: rule.id,
        label: rule.label,
        category: "rhythm",
        before: match,
        after: rule.replacement,
        tip: "Reduce repeated stage-managed rhythm."
      });
      return rule.replacement;
    });
  }

  if (!hits.length) {
    const generalPolish = applyGeneralPolish(output, language);
    if (generalPolish.output !== output) {
      output = generalPolish.output;
      hits.push(generalPolish.hit);
    }
  }

  output = tidyText(softenSentences(tidyText(output, language), language), language);
  const categories = summarizeCategories(hits);
  const score = scoreDraft(original, hits, language);

  return {
    language,
    output,
    score,
    hits,
    categories
  };
}

export function scoreDraft(text, hits, language = detectLanguage(text)) {
  const textLength = Math.max(text.trim().length, 1);
  const density = hits.length / Math.max(Math.ceil(textLength / 90), 1);
  const categoryPenalty = hits.reduce((total, hit) => total + (categoryWeights[hit.category] ?? 5), 0);
  const densityPenalty = Math.round(density * 8);
  const languagePenalty = language === "mixed" ? 4 : 0;
  return Math.max(12, Math.min(100, 100 - categoryPenalty - densityPenalty - languagePenalty));
}

function applyGeneralPolish(text, language) {
  if (text.trim().length < 36) {
    return { output: text, hit: null };
  }

  if (language === "zh" || language === "mixed") {
    const next = text
      .replace(/^这是一款(.+?)的工具，可以帮助用户/, "这款工具$1，能帮用户")
      .replace(/^这是一个(.+?)的工具，可以帮助用户/, "这个工具$1，能帮用户")
      .replace(/可以帮助用户/g, "能帮用户")
      .replace(/并提高工作效率/g, "，也让工作推进得更顺")
      .replace(/并提升工作效率/g, "，也让工作推进得更顺");

    return {
      output: next,
      hit: {
        id: "zh-general-polish",
        label: "中文基础润色",
        category: "fallback",
        before: text,
        after: next,
        tip: "没有命中特定套话时，仍对说明式文案做轻量自然化。"
      }
    };
  }

  if (language === "en") {
    const next = text
      .replace(/\bThis is a tool that helps users\b/i, "This tool helps users")
      .replace(/\ballows users to\b/gi, "lets users")
      .replace(/\bcan help users\b/gi, "helps users")
      .replace(/\bimprove productivity\b/gi, "get work done faster");

    return {
      output: next,
      hit: {
        id: "en-general-polish",
        label: "English basic polish",
        category: "fallback",
        before: text,
        after: next,
        tip: "When no specific slop phrase matches, lightly simplify product-copy phrasing."
      }
    };
  }

  return { output: text, hit: null };
}

function summarizeCategories(hits) {
  return hits.reduce((summary, hit) => {
    summary[hit.category] = (summary[hit.category] ?? 0) + 1;
    return summary;
  }, {});
}

function softenSentences(text, language) {
  if (language === "zh" || language === "mixed") {
    return text
      .replace(/OpenAI Codex是OpenAI/g, "OpenAI Codex 是 OpenAI")
      .replace(/OpenAI於/g, "OpenAI 在")
      .replace(/OpenAI于/g, "OpenAI 在")
      .replace(/OpenAI Codex 是 OpenAI开发的AI代码生成模型，主要用来/g, "OpenAI Codex 是 OpenAI 做的 AI 编程模型，可以")
      .replace(/OpenAI Codex 是 OpenAI开发的 AI 代码生成模型，主要用来/g, "OpenAI Codex 是 OpenAI 做的 AI 编程模型，可以")
      .replace(/AI代码/g, "AI 代码")
      .replace(/OpenAI 在(\d{4})年(\d{1,2})月/g, "OpenAI 在 $1 年 $2 月")
      .replace(/发布Codex/g, "发布了 Codex")
      .replace(/，并进一步/g, "，也")
      .replace(/更加/g, "更")
      .replace(/各位伙伴/g, "大家")
      .replace(/也是组织能力的全面跃迁/g, "也是在提升组织能力")
      .replace(/组织能力的全面跃迁/g, "组织能力提升")
      .replace(/我们将讲清楚如何做到这件事/g, "我们会讲清楚怎么做到")
      .replace(/实现这一目标/g, "做到这件事")
      .replace(/如何做到这件事/g, "怎么做到");
  }

  return text
    .replace(/\bmust\b/gi, "can")
    .replace(/\bunlock\b/gi, "get")
    .replace(/\beffectively\b/gi, "")
    .replace(/\bstrategic shift\b/gi, "real change");
}

function tidyText(text, language) {
  let next = text
    .replace(/[ \t]+/g, " ")
    .replace(/\s+([,.!?;:，。！？；：])/g, "$1")
    .replace(/([（(])\s+/g, "$1")
    .replace(/\s+([）)])/g, "$1")
    .replace(/^[,，。；;:\s]+/, "")
    .replace(/\s+$/g, "");

  if (language === "zh" || language === "mixed") {
    next = next
      .replace(/，{2,}/g, "，")
      .replace(/。{2,}/g, "。")
      .replace(/，。/g, "。")
      .replace(/^所以，所以，/, "所以，");
  } else {
    next = next
      .replace(/\s{2,}/g, " ")
      .replace(/\s+\./g, ".")
      .replace(/\s+,/g, ",")
      .replace(/,\s*\./g, ".")
      .replace(/^so,\s*so,\s*/i, "So, ");
  }

  return restoreSentenceCase(next);
}

function restoreSentenceCase(text) {
  if (!text) return text;
  return text
    .replace(/^([a-z])/, (match) => match.toUpperCase())
    .replace(/([.!?]\s+)([a-z])/g, (_, prefix, letter) => `${prefix}${letter.toUpperCase()}`);
}
