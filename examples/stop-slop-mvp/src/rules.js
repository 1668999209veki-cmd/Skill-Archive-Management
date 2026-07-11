export const phraseRules = [
  {
    id: "zh-fast-era",
    language: "zh",
    pattern: /在当今(?:这个)?(?:快速发展|瞬息万变|日新月异)的(?:时代|社会|数字时代)[，,]*/g,
    replacement: "",
    label: "中文空泛开场",
    category: "cliche",
    tip: "删掉模板化时代背景，直接说事。"
  },
  {
    id: "zh-important-note",
    language: "zh",
    pattern: /(?:值得注意的是|需要指出的是|不可否认的是)[，,]*/g,
    replacement: "",
    label: "中文提示语",
    category: "filler",
    tip: "如果后文就是重点，不需要先提醒读者。"
  },
  {
    id: "zh-summary",
    language: "zh",
    pattern: /(?:总的来说|综上所述|由此可见)[，,]*/g,
    replacement: "所以，",
    label: "中文总结套话",
    category: "structure",
    tip: "保留转折或结论关系，换成更口语的连接。"
  },
  {
    id: "zh-empower",
    language: "zh",
    pattern: /赋能/g,
    replacement: "帮助",
    label: "中文商业黑话",
    category: "buzzword",
    tip: "把抽象词换成具体动作。"
  },
  {
    id: "zh-create",
    language: "zh",
    pattern: /打造/g,
    replacement: "做出",
    label: "中文商业黑话",
    category: "buzzword",
    tip: "用更普通的动词。"
  },
  {
    id: "zh-deep-dive",
    language: "zh",
    pattern: /(?:深入探讨|深度剖析|全面解析)/g,
    replacement: "讲清楚",
    label: "中文夸张动词",
    category: "tone",
    tip: "少承诺大而全，改成可交付的表达。"
  },
  {
    id: "zh-ai-term",
    language: "zh",
    pattern: /人工(?:智慧|智能)/g,
    replacement: "AI",
    label: "中文术语过重",
    category: "tone",
    tip: "常见技术词可以用更轻的写法。"
  },
  {
    id: "zh-code-term",
    language: "zh",
    pattern: /(?:程序)?(?:代碼|代码)/g,
    replacement: "代码",
    label: "中文术语统一",
    category: "tone",
    tip: "统一术语，减少翻译腔。"
  },
  {
    id: "zh-mainly-used-for",
    language: "zh",
    pattern: /主要用[于於]/g,
    replacement: "主要用来",
    label: "中文说明腔",
    category: "filler",
    tip: "把说明书式表达改成日常表达。"
  },
  {
    id: "zh-according-to-prompt",
    language: "zh",
    pattern: /根[据據]自然(?:語言|语言)提示/g,
    replacement: "按自然语言提示",
    label: "中文翻译腔",
    category: "tone",
    tip: "压缩绕口的介词结构。"
  },
  {
    id: "zh-traditional-verbs",
    language: "zh",
    pattern: /(?:開發|發佈|發布|補全)/g,
    replacement: (match) => ({
      "開發": "开发",
      "發佈": "发布",
      "發布": "发布",
      "補全": "补全"
    })[match],
    label: "中文术语统一",
    category: "tone",
    tip: "统一简繁和常用写法。"
  },
  {
    id: "zh-private-beta-access",
    language: "zh",
    pattern: /(?:并|並)通[过過]\s*API\s*(?:私人|私有)?(?:測試|测试)版提供(?:訪問|访问)/g,
    replacement: "并通过 API 私人测试版开放试用",
    label: "中文说明腔",
    category: "filler",
    tip: "把直译的 access 改成中文里更自然的说法。"
  },
  {
    id: "zh-intensifier",
    language: "zh",
    pattern: /(?:极大地|显著地|有效地|全面地|持续地|不断地|充分地)/g,
    replacement: "",
    label: "中文弱化副词",
    category: "intensifier",
    tip: "删掉没有证据支撑的程度词。"
  },
  {
    id: "zh-vital",
    language: "zh",
    pattern: /至关重要/g,
    replacement: "很重要",
    label: "中文绝对化表达",
    category: "tone",
    tip: "把过重的判断降到自然语气。"
  },
  {
    id: "zh-not-only",
    language: "zh",
    pattern: /不仅(?:仅)?是/g,
    replacement: "不只是",
    label: "中文排比模板",
    category: "structure",
    tip: "降低模板感。"
  },
  {
    id: "zh-but-also",
    language: "zh",
    pattern: /更是/g,
    replacement: "也是",
    label: "中文排比模板",
    category: "structure",
    tip: "避免过度升华。"
  },
  {
    id: "en-landscape",
    language: "en",
    pattern: /\bin today'?s (?:fast[- ]paced|ever[- ]evolving|rapidly changing) (?:digital )?landscape,?\s*/gi,
    replacement: "",
    label: "English generic opener",
    category: "cliche",
    tip: "Skip the scene-setting and begin with the point."
  },
  {
    id: "en-note",
    language: "en",
    pattern: /\b(?:it is important to note that|it'?s worth noting that|needless to say),?\s*/gi,
    replacement: "",
    label: "English throat-clearing",
    category: "filler",
    tip: "If it matters, say it directly."
  },
  {
    id: "en-delve",
    language: "en",
    pattern: /\bdelve into\b/gi,
    replacement: "look at",
    label: "English AI verb",
    category: "tone",
    tip: "Use a plainer verb."
  },
  {
    id: "en-delves",
    language: "en",
    pattern: /\bdelves into\b/gi,
    replacement: "looks at",
    label: "English AI verb",
    category: "tone",
    tip: "Use a plainer verb."
  },
  {
    id: "en-delving",
    language: "en",
    pattern: /\bdelving into\b/gi,
    replacement: "looking at",
    label: "English AI verb",
    category: "tone",
    tip: "Use a plainer verb."
  },
  {
    id: "en-leverage",
    language: "en",
    pattern: /\b(?:leverage|leverages|leveraging)\b/gi,
    replacement: "use",
    label: "English business verb",
    category: "buzzword",
    tip: "Plain words usually sound more human."
  },
  {
    id: "en-utilize",
    language: "en",
    pattern: /\b(?:utilize|utilizes|utilizing|utilized)\b/gi,
    replacement: "use",
    label: "English inflated verb",
    category: "buzzword",
    tip: "Use shorter common verbs."
  },
  {
    id: "en-seamless",
    language: "en",
    pattern: /\bseamlessly\b\s*/gi,
    replacement: "",
    label: "English vague adverb",
    category: "intensifier",
    tip: "Remove vague polish unless you can prove it."
  },
  {
    id: "en-robust",
    language: "en",
    pattern: /\brobust\b/gi,
    replacement: "solid",
    label: "English vague adjective",
    category: "tone",
    tip: "Prefer a grounded adjective."
  },
  {
    id: "en-transformative",
    language: "en",
    pattern: /\btransformative\b/gi,
    replacement: "useful",
    label: "English overclaim",
    category: "tone",
    tip: "Tone down claims that sound inflated."
  },
  {
    id: "en-not-only",
    language: "en",
    pattern: /\bnot only\b/gi,
    replacement: "not just",
    label: "English parallelism",
    category: "structure",
    tip: "Make the sentence feel less templated."
  },
  {
    id: "en-but-also",
    language: "en",
    pattern: /\bbut also\b/gi,
    replacement: ". It is also",
    label: "English parallelism",
    category: "structure",
    tip: "Break up stock contrast patterns."
  },
  {
    id: "en-summary",
    language: "en",
    pattern: /\b(?:in conclusion|to summarize|overall),?\s*/gi,
    replacement: "So, ",
    label: "English summary phrase",
    category: "structure",
    tip: "Use a smaller transition."
  }
];

export const rhythmRules = [
  {
    id: "remove-marketing-triples",
    pattern: /\b(faster),\s*(smarter),\s*and\s*(better)\b/gi,
    replacement: "$1 and clearer",
    label: "Marketing triple"
  },
  {
    id: "trim-many-exclaims",
    pattern: /!{2,}/g,
    replacement: "!",
    label: "Repeated exclamation"
  }
];

export const sampleDrafts = [
  {
    id: "zh-product",
    label: "中文产品文案",
    text: "在当今快速发展的数字时代，企业需要不断地赋能团队，打造更加高效、智能、全面的工作流。值得注意的是，这不仅仅是一次工具升级，更是组织能力的全面跃迁。总的来说，我们将深入探讨如何有效地实现这一目标。"
  },
  {
    id: "zh-email",
    label: "中文邮件",
    text: "不可否认的是，本次方案对业务增长至关重要。我们希望通过这套机制持续地提升协作效率，并进一步打造可复制的最佳实践。综上所述，请各位伙伴积极推进。"
  },
  {
    id: "en-product",
    label: "English Product",
    text: "In today's fast-paced digital landscape, teams must leverage robust solutions to seamlessly unlock transformative outcomes. It is important to note that this is not only a productivity upgrade but also a strategic shift. In conclusion, this article delves into how to utilize the platform effectively."
  }
];
