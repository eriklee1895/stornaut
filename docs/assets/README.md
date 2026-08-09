# Assets

- [`ui-concepts/`](ui-concepts/)：页面候选、canonical Light/Dark 参考、prompt 与选择记录。
- [`brand-concepts/`](brand-concepts/)：Logo 探索、批准方向与生产资产要求。

本目录中的 raster 图片和示例数据不是实现真值。行为、安全、文案、默认选择和状态机以 [`../design/`](../design/) 中的批准规格为准。生产品牌资产需要从统一矢量 master 重绘，不能直接发布概念 PNG。

## Sources and provenance

- 现有 UI/UX 与品牌概念图由 `$erik-gpt-image-2` skill 使用 OpenAI `gpt-image-2` Image API 生成；历史文档中的 `built-in imagegen` 是旧称。
- 后续 raster 素材优先复用仓库已有资产；需要新素材时可以使用 Web 搜索或 `$erik-gpt-image-2`。
- Web 素材进入仓库前必须记录来源 URL、作者/版权、许可证、允许用途、下载日期和是否修改。找不到明确许可证时只作研究参考，不提交为产品资产。
- `$erik-gpt-image-2` 输出必须保留 sibling metadata JSON 或等价的 prompt/model/size/timestamp 记录。API key、base URL credential 和本地 `.env` 不得提交。
- 生成图需要可读文字时使用 high quality 和明确的 verbatim 文案，但不得把图内文字当作可访问 UI 或本地化实现。
- gpt-image-2 适用于 raster 概念图、插画和生产候选，不用于最终 SVG/vector Logo、确定性图表或代码原生 UI。
- 新资产是否可直接发布必须在对应设计/实现迭代中明确；概念资产默认不可直接 shipping。
