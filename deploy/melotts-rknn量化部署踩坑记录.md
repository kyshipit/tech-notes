<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# MeloTTS RKNN 量化部署踩坑记录

> 本文档适合第一次接触 AI 模型部署的开发者阅读。内容涵盖从 PyTorch 模型到 RK3588 NPU 推理的全过程，包含所有踩坑记录、技术细节和最终结论。

## 一、项目背景

### 1.1 项目概述

MeloTTS 是一个基于 PyTorch 实现的开源文本转语音（TTS）模型，底层采用 VITS/VITS2 架构，以高质量语音合成为设计目标。RK3588 开发板搭载了专门为 AI 推理加速的 NPU（神经网络处理单元）。

本项目的目标是将 MeloTTS 从 PyTorch 格式转换为 RKNN 格式，使其能够利用 RK3588 NPU 的硬件加速能力进行推理，从而实现更高效的语音合成。

### 1.2 延迟与音质的权衡

MeloTTS 是一个“音质优先”的 TTS 模型，其 VITS/VITS2 架构为高质量语音合成优化，而非低延迟推理。实测在 RK3588 NPU 上单句推理耗时稳定在 1.8–2.2 秒，且该延迟与输入文本长度无关。这是架构特性决定的，不因模型转换而改变。

本项目记录了完整的转换过程和踩坑经验，包括 ONNX 导出、动态维度处理、RKNN 转换、INT8 量化及校准数据设计等环节，可作为同类 TTS 模型部署到 RK3588 NPU 的参考。

### 1.3 整体技术路线

**通用转换流程：**
```
PyTorch 模型
    ↓   ① onnxsim.simplify()
    ↓   ② torch.onnx.export()
ONNX 模型
    ↓   ③ rknn-toolkit2
    ↓   ④ 量化（提供校准数据）
RKNN 模型
    ↓   ⑤ 部署到 NPU
```

**本项目实际执行情况：**
| 阶段        | 计划                               | 实际结果                                                     |
| :---------- | :--------------------------------- | :----------------------------------------------------------- |
| ① 优化模型  | `onnxsim.simplify` 优化模型        | Encoder 被固化为完全静态，Decoder 保留 `dim_param` 标记（元数据动态，实际静态） |
| ② ONNX 导出 | 配置 `dynamic_axes` 支持动态 shape | `dynamic_axes` 无效，Tracing 机制已固化，回退静态 256        |
| ③ 转换工具  | 配置 `dynamic_input` 支持多长度    | 多长度失败，锁定单长度 `seq_lens=256`                        |
| ④ INT8 量化 | 提供校准数据，全模型 INT8          | Encoder 失败（`Less` 算子类型冲突）；Decoder 成功但音质下降  |

最终可用方案：
- Encoder：FP16 静态（INT8 量化失败）
- Decoder：FP16 固定长度（INT8 可量化但音质下降，不作为生产推荐）

**ONNX 的作用：** ONNX（Open Neural Network Exchange）是 AI 领域的中间格式，几乎所有深度学习框架都能导出 ONNX，几乎所有推理引擎都能读取 ONNX。它充当了 PyTorch 和 RKNN 之间的“翻译中间人”。

## 二、PyTorch → ONNX 导出

### 2.1 仓库选择：官方 vs 社区版

MeloTTS 有多个版本，对比如下：

| 对比项                     | 官方仓库 (myshell-ai/MeloTTS)                           | 修改版 (mmontol/MeloTTS)                  |
| :------------------------- | :------------------------------------------------------ | :---------------------------------------- |
| 主分支是否有 ONNX 导出功能 | ❌ 主分支没有                                            | ✅ 有（export_onnx 方法 + export.py 脚本） |
| 补充说明                   | 有PR #276尝试添加 ONNX支持，但尚未合并 | —                                         |
| 代码来源                   | [MyShell.ai](https://myshell.ai/) 官方发布              | 从官方 fork 后，由 mmontol 修改           |

**结论**：必须使用 `mmontol/MeloTTS` 这个社区版。官方仓库主分支只能做推理，暂不支持导出 ONNX（虽然官方曾通过 PR #276 尝试添加该功能，但尚未合并）。核心区别：官方仓库主分支是“纯 TTS 引擎”，修改版是“TTS 引擎 + ONNX 导出工具箱”。

### 2.2 导出步骤与依赖问题

**环境准备与代码克隆：**

```
git clone https://github.com/mmontol/MeloTTS.git
cd MeloTTS
```

**问题一：RuntimeError: Failed initializing MeCab**

原因：MeloTTS 启动时会加载所有语言模块（包括日语），日语需要 mecab 分词器 + unidic 词典

解决：pip install unidic-lite

**注意**：MeCab 是日语的词法分析器（分词工具）。MeloTTS 虽然是中文 TTS，但代码会尝试加载所有语言支持。unidic-lite 是轻量版词典，通过 pip 直接安装即可绕过完整下载。

另外，如果不需要日语支持，可以修改 `melo/text/cleaner.py`，直接删掉 japanese 相关的导入：

```
from . import chinese, english, chinese_mix, korean, french, spanish
language_module_map = {"ZH": chinese, "EN": english, 'ZH_MIX_EN': chinese_mix,
        'KR': korean, 'FR': french, 'SP': spanish, 'ES': spanish}
```

同时修改 `melo/text/japanese.py`，在 MeCab 初始化失败时静默降级：

```
try:
    _TAGGER = MeCab.Tagger()
except Exception:
    _TAGGER = None
```

**问题二：NameError: name 'language_id_map' is not defined**

原因：社区版的 api.py 中 export_onnx 函数使用了 language_id_map，但文件顶部缺少导入

解决：在 api.py 顶部添加一行：from .text import language_id_map

**注意**：language_id_map 是 MeloTTS 中语言名称（如 "ZH"）到数字 ID（如 1）的映射表。模型内部用数字 ID 来区分不同语言。

### 2.3 torch.onnx.export() 核心参数详解

这是整个导出过程最核心的函数。把它理解为"翻译官"：

```
torch.onnx.export(
    model,                         # PyTorch 模型
    inputs,                        # 示例输入，告诉翻译官"输入长什么样"
    "model.onnx",                  # 输出文件名
    opset_version=16,              # 使用哪个版本的"翻译规则"
    do_constant_folding=True,      # 开启优化：把固定不变的部分提前算好
    keep_initializers_as_inputs=False,  # 优化后把多余输入删掉
    input_names=["x", ...],        # 给输入起名字
    output_names=["y", ...],       # 给输出起名字
    dynamic_axes={...}             # 声明哪些维度是可变的
)
```

**逐个参数解释：**

| 参数                                | 通俗解释               | 为什么这样设置                                               |
| :---------------------------------- | :--------------------- | :----------------------------------------------------------- |
| `opset_version=16`                  | 翻译规则的版本号       | 版本 16 对"可变尺寸"支持更好，避免低版本算子不支持           |
| `do_constant_folding=True`          | 提前计算固定不变的部分 | 消除 `Expand` 节点的动态占位符，避免 RKNN 报 `invalid expand shape` |
| `keep_initializers_as_inputs=False` | 将常量从输入列表中移除 | 配合常量折叠精简模型                                         |
| `dynamic_axes`                      | 声明哪些维度可变       | 序列长度随文本变化，需声明为动态                             |

**关于 `ja_bert` 输入数量：** 是否出现在 ONNX 输入中，以实际导出的 ONNX 文件为准。运行以下命令确认：
```
python -c "import onnx; m=onnx.load('encoder.onnx'); print([i.name for i in m.graph.input])"
```
- 输出包含  → 输入为 8 个，校准数据需包含，输出不包含 → 输入为 7 个，校准数据无需包含
- 校准数据文件数量须与 ONNX 实际输入数量一致。

### 2.4 dynamic_axes——如何声明"可变尺寸"

```
dynamic_axes={
    "x": {0: "batch", 1: "seq_len"},         # x 的第0维叫 batch，第1维叫 seq_len
    "tone": {0: "batch", 1: "seq_len"},
    "lang_ids": {0: "batch", 1: "seq_len"},
    "ja_bert": {0: "batch", 1: "channels", 2: "seq_len"},
    "logw": {0: "batch", 1: "channels", 2: "seq_len"},
    # ...
}
```

**核心概念**：ONNX 模型中的维度有两种表示方式：

| 表示方式             | 含义                   | 示例                                               |
| :------------------- | :--------------------- | :------------------------------------------------- |
| dim_value: 1         | 固定值，永远不会变     | dim_value: 1（batch 永远为 1）                     |
| dim_param: "seq_len" | 动态占位符，运行时可变 | dim_param: "seq_len"（文本短则值小，文本长则值大） |

**命名原则很重要**：

| 写法                                              | 结果                                                        | 评价                                  |
| :------------------------------------------------ | :---------------------------------------------------------- | :------------------------------------ |
| "logw": {2: "seq_len"}                            | 第3维叫 seq_len，前两维自动生成 Addlogw_dim_0/Addlogw_dim_1 | ❌ 不推荐，RKNN 会因名称不清而推断失败 |
| "logw": {0: "batch", 1: "channels", 2: "seq_len"} | 三个维度都有清晰的名字                                      | ✅ 推荐                                |

⚠️ **重要警告**：dim_param 只是 ONNX 文件里的"元数据标签"，不代表模型内部真的支持动态变化。如果模型代码里有 `y_lengths = 2 * x_length` 这种硬编码，dynamic_axes 就只是"纸面动态"——看着像动态，实际跑起来还是固定长度。

### 2.5 onnxsim.simplify()——ONNX 模型"减肥"

```
sim_model, _ = onnxsim.simplify(encoder_name)
onnx.save(sim_model, encoder_name)
```

**这个函数做了什么？**

1. 常量折叠：把固定不变的计算提前算好
2. 冗余消除：删掉没有实际作用的操作
3. 算子融合：把多个小操作合并成一个

**它对动态形状的影响**：

| 模型                      | 加上 simplify 后的效果                        |
| :------------------------ | :-------------------------------------------- |
| Encoder + 无 dynamic_axes | 所有维度都变成固定值（dim_value），完全静态   |
| Decoder + 有 dynamic_axes | 保留 dim_param: "seq_len"，元数据层面仍是动态 |

**为什么会有这种差异？** Encoder 内部的 ScatterND+Slice 操作在简化后，其形状依赖被解析为固定值（256），所以所有维度都静态化了。Decoder 结构更简单，seq_len 的依赖没有被完全消除。

## 三、ONNX → RKNN 转换

### 3.1 RKNN 动态形状的"预设菜单"模式

很多人的第一反应是："既然模型支持动态，那直接转成动态的 RKNN 就行了。"

但 RKNN 的动态形状和 PyTorch/ONNX 的动态形状不是一回事。

```
rknn.config(
    target_platform='rk3588',
    dynamic_input=[
        [[1, 64], [1], [1], [1, 64], [1, 64], [1, 768, 64], [1], [1]],
        [[1, 128], [1], [1], [1, 128], [1, 128], [1, 768, 128], [1], [1]],
        [[1, 256], [1], [1], [1, 256], [1, 256], [1, 768, 256], [1], [1]],
    ]
)
```

**核心认知**：

- RKNN 的"动态"不是"输入多长就计算多长"，而是 **"预设菜单"模式**。
- 必须在转换时把 **所有可能用到的形状** 都列出来。
- NPU 会为每一种形状生成一套优化指令。
- 推理时你只能从预设菜单里选一个，不能临时"自定义"。

**类比**：这不是"按需点菜"，而是"提前买好套餐"——你只能从套餐 A/B/C 里选，不能自己随意搭配。

### 3.2 Decoder 的 dynamic_input 形状配置

```
shapes = [
    [1, 2*seq_len, 256],   # attn: [batch, 2*seq_len, attn_dim]
    [1, 1, 2*seq_len],     # y_mask: [batch, 1, 2*seq_len]
    [1, 256, 1],           # g: [batch, 256, 1]（固定）
    [1, 192, seq_len],     # m_p: [batch, 192, seq_len]
    [1, 192, seq_len],     # logs_p: [batch, 192, seq_len]
    [1]                    # noise_scale: [1]（固定）
]
```

**关键点**：

- attn 的第二维是 2*seq_len，因为 `y_lengths = 2 * x_length`
- g 和 noise_scale 是固定维度，不参与动态

### 3.3 多长度配置（128/256/512）失败原因

我们最初尝试了 `seq_lens=[128, 256, 512]`，转换失败，报错 MatMul dimension mismatch。

**原因分析**：

- RKNN 需要为 3 种不同的 seq_len 分别做形状推断。
- Decoder 内部包含大量 MatMul、Expand 等对形状敏感的操作。
- 某些组合（比如 128 和 512）下的维度推断会出错。
- 最终只能接受 **单长度（256）**。

**经验教训**：不要追求"完美动态"，先用一个长度验证可行，再逐步扩展。

### 3.4 op_target——强制算子在 CPU 执行的正确方式

有时候 NPU 不支持某些算子，需要强制它们在 CPU 上运行：

```
rknn.config(
    target_platform='rk3588',
    op_target={'/sdp/flows.7/Less_output_0': 'cpu'}
)
```

⚠️ **常见错误写法**：

```
op_target={'Less': 'cpu'}  # ❌ 错误！Less 是算子类型名，不是输出 tensor 名
```

**正确写法要求**：

- 键必须是 **算子的输出 tensor 名**（不是算子类型名）
- 输出 tensor 名需要通过 **精度分析（accuracy analysis）** 获取
- 官方文档中 op_target 的标准用法是按输出 tensor 名指定，未定义按算子类型名批量指定的写法

**获取正确 tensor 名的方法**：

1. 精度分析（accuracy analysis）返回结果
2. Netron 可视化查看算子输出边名称
3. 从 ONNX 节点打印 `node.output[0]`

## 四、核心发现：假动态问题

### 4.1 根本原因：Tracing 机制的天然局限

`torch.onnx.export` 默认基于 **Tracing（追踪）** 机制导出模型。它的工作方式是：**用你提供的示例输入实际运行一次模型，并记录下所有经过的张量操作**。

- **致命缺陷**：Tracing 无法处理依赖数据本身的条件分支或循环。它只能记录下"示例输入"走过的那一条固定路径。可以把它理解为一个录屏软件，它只录下了你操作电脑的整个过程，却不知道你为什么要那样操作。
- 虽然设置了 `dynamic_axes`，但 torch.onnx.export 默认采用 Tracing 机制导出模型，该机制会记录示例输入执行路径上的张量形状信息，并将这些形状信息写入 ONNX 图。
- 模型内部存在对形状的依赖：MeloTTS 模型内部存在 x.size() 等依赖张量形状的操作。在 Tracing 过程中，示例输入的具体长度（如 256）会被记录下来，后续基于该值的计算会被固化为以 256 为基础的静态图。
- **常量折叠的"推波助澜"**：开启的 `do_constant_folding=True` 会进一步将图中所有能确定的常量计算提前算出结果。既然 `x_length` 已经被 Tracing 固化为常量 256，那么 `y_lengths = 2 * x_length` 这样的计算就会被直接折叠成常量 512，整个计算图因此完全固化。
- **dynamic_axes 的"无能为力"**：`dynamic_axes` 的作用更像是在 ONNX 模型的**元数据**上做一个标记，告诉推理引擎"这个维度理论上是可以变的"。但它**无法改变已经被 Tracing 固化的计算图本身**。因此，即使你标记了 `seq_len`，模型内部的 Reshape、MatMul 等算子，其期望的输入形状已经被固化成了 512。当你尝试传入 `seq_len=128` 的数据时，形状不匹配，自然会报错。

### 4.2 直接原因：x_length 被固化为 256

在社区版的 `export_onnx` 函数中，x_length 被硬编码为 256：

```
def export_onnx(self, ..., x_length=256, ...):
    # ...
    x_lengths = torch.LongTensor([x_length])
    # ...
```

这个 **256**，就是 Tracing 过程中被"录下来"的那个具体数值。从这个点开始，整个计算图都围绕"序列长度为 256"这个前提被构建，并被 `do_constant_folding` 进一步固化。

### 4.3 如何验证真动态？

用 ONNX Runtime 输入不同 seq_len，检查输出形状是否变化：

```
# 通用验证代码模板
import onnxruntime as ort
import numpy as np
sess = ort.InferenceSession('model.onnx')
# 正确构造不同 seq_len 的输入
out1 = sess.run(None, make_inputs(seq_len=128))
out2 = sess.run(None, make_inputs(seq_len=256))
print(out1[0].shape, out2[0].shape)  # 相同=假动态，不同=真动态
```

- 如果输出形状 **不同** → ✅ 真动态
- 如果输出形状 **相同** 或 **报错** → ❌ 假动态

**实测结果**：MeloTTS 输出相同 → 假动态。

**假动态的典型表现**：

- ONNX 打印显示 `dim_param: "seq_len"` → 只是元数据声明
- Netron 显示 `[1,1,262144]` → `y_lengths = 2 * x_length` → 固化为 512 内部已固化
- ONNX Runtime 测试失败 → 无法处理不同 seq_len
- RKNN 推理时间固定 → 计算图恒定

### 4.4 结论：为什么必然是"完全静态"？

- Tracing 机制将所有依赖形状的操作固化。
- `x_length` 被硬编码为 256，为 Tracing 提供了具体的固化值。
- 常量折叠又将基于这些固化的计算进一步折叠。
- 最终，`dynamic_axes` 的标记只是"纸上谈兵"，无法改变已被固化的计算图。

这个模型在导出时，其计算图就已经被"拍扁"成了一个只认识 `seq_len=256` 的静态模型。你后续在 RKNN 中做的所有关于 `seq_lens` 的设置，都只是在和这个被固化后的静态图"对话"。

### 4.5 真动态的必要条件与社区版的现实妥协

| 条件                                                         | 难度                                             |
| :----------------------------------------------------------- | :----------------------------------------------- |
| 修改模型源码，恢复 `y_lengths = sum(w_ceil)`（原始 Duration Predictor） | 高                                               |
| 导出时 `do_constant_folding=False`                           | 中                                               |
| 使用 `torch.jit.script` 而非 tracing                         | 极高（MeloTTS 含大量 Python 控制流，几乎不可能） |

`mmontol/MeloTTS` 选择 tracing + 硬编码 `y_lengths` 的方式，是为了**保证导出成功率**。这是一种工程取舍：牺牲"完美动态"来换取"基本可用"。

**如何实现真动态输出？** 必须同时满足：

1. **保留原始 duration prediction 逻辑**：

```
# 删除硬编码行！
# y_lengths = torch.FloatTensor([2 * x_length])

# 改回动态计算
w = torch.exp(logw) * x_mask * length_scale
w_ceil = torch.ceil(w)
y_lengths = torch.clamp_min(torch.sum(w_ceil, [1, 2]), 1).long()
```

1. **确保所有上采样操作基于 y_lengths 动态进行**：不能有 `F.pad(..., max_len)`，不能有固定 `size=` 的 `interpolate`。
2. **导出时使用 symbolic tracing（非 tracing）**：`torch.onnx.export` 默认用 `torch.jit.trace`，无法处理动态控制流。应改用 `torch.jit.script`（但 MeloTTS 含大量 Python 控制流，可能失败）。
3. **关闭常量折叠**：`do_constant_folding=False`

### 4.6 MeloTTS 架构流式分析

MeloTTS 基于 VITS（VITS2）架构，核心特点是 **非自回归、端到端**：

| 组件               | 是否流式？   | 说明                                                      |
| :----------------- | :----------- | :-------------------------------------------------------- |
| Text Encoder       | ❌ 非流式     | 使用 Transformer 全注意力机制，需看到整句才能输出文本表征 |
| Duration Predictor | ❌ 非流式     | 预测每个音素持续帧数，依赖全局文本特征                    |
| Flow-based Decoder | ❌ 非流式     | 一次性生成整段梅尔频谱，T 由时长预测模块决定              |
| Vocoder (HiFi-GAN) | ⚠️ 有条件支持 | 标准实现为全图生成，存在支持流式合成的因果化变体          |

**关键瓶颈**：MeloTTS 的 Decoder 必须等整段梅尔频谱完全生成后，才能交给 Vocoder。因此即使 Vocoder 有流式变体，在标准 MeloTTS 架构中，单句推理必须等全量生成完成后才能输出。

**关于“流式合成”的澄清**：MeloTTS 官方提到的“流式合成”（streaming synthesis）与逐帧/逐 token 输出是两回事。根据官方 API 实现，`/tts/stream` 接口提供的是 句子级流式响应（sentence-level streaming responses），模型不会输出 token 级别的音频。

| 能力               | 是否支持 | 说明                                                         |
| :----------------- | :------- | :----------------------------------------------------------- |
| 按句子边界分段合成 | ✅ 支持   | 长文本按标点断句，逐句合成并输出。这是 MeloTTS “流式合成”的实际含义 |
| 单句推理时提前输出 | ❌ 不支持 | 单句必须等全量生成完成                                       |
| 逐帧/逐 token 输出 | ❌ 不支持 | 官方明确说明模型不输出 token 级别的音频                      |
| 后处理裁剪播放     | ✅ 支持   | 全量生成后按实际帧数裁剪，改善感知延迟                       |


## 五、INT8 量化

### 5.1 什么是量化？为什么要量化？

量化是将模型权重和激活从 FP32 转换为 INT8 的过程。可以理解为“有损压缩”：INT8 量化需要校准数据来统计激活值分布，计算 scale 和 zero_point，决定 FP32 到 INT8 的映射方式。

**FP16 vs INT8 量化的区别：**

- FP16 转换：不需要校准数据，精度损失几乎可忽略
- INT8 量化：需要校准数据，体积压缩更明显，但精度损失更大

**INT8 量化的好处：**

- 模型体积缩小（129MB → 67MB）
- 内存占用降低

**INT8 量化的代价：**

- TTS 生成式任务中音质下降（杂音）
- 部分模型结构无法 INT8 量化（如 Encoder 因 Less 算子报错失败）
- 推理时间无明显提升

**本项目 INT8 量化验证结果：**

| 验证项                               | 结果                      |
| :----------------------------------- | :------------------------ |
| Netron 显示结构不变，dtype 变为 int8 | ✔️ 正确                    |
| Decoder 量化✅，体积从 129MB → 67MB | ✔️ 符合 INT8 量化预期      |
| 推理时间变化                         | ❌ 无明显提升              |
| 播放音质                            | ❌ 有杂音，不清晰          |
| Encoder 量化❌失败                  | ❌ Less 算子类型冲突，失败 |

### 5.1.5 RKNN 量化的机制

RKNN 的 PTQ（训练后量化，Post-Training Quantization）在 `do_quantization=True` 时，对模型中不同对象的处理逻辑如下：

| 对象               | 量化行为              | 是否可控                                               |
| :----------------- | :-------------------- | :----------------------------------------------------- |
| **模型权重**       | 默认统一量化 INT8     | 可通过混合量化（disable_quantize_layer）进行细粒度控制 |
| **模型内部激活值** | 默认统一量化 INT8     | 由校准数据集决定，行为基本固定                         |
| **图内常量节点**   | 永远保持 FP32，不量化 | ❌ 不可控，永远不变                                     |

**核心规则**：

- `do_quantization=True` 时，模型内部的权重和激活值会默认量化为 INT8。
- 图内 Constant 常量节点永远不量化，始终是 FP32。

**重要补充**：

- 外部输入数据（如传给 `sdp_ratio` 的标量）在推理时可以灵活指定数据类型，并非强制 INT8。

### 5.2 量化参数

python

```
ret = rknn.build(
    do_quantization=True,   # 开启 INT8 量化
    dataset='dataset.txt'   # 校准数据集索引文件——必须提供！
)
```

**为什么必须提供校准数据？** 量化不是"直接砍掉小数位"，而是要找一种最优的映射方式。比如有一组浮点数 [0.1, 0.5, 1.2, 3.8]，要压缩到 0~255 的整数范围，需要先知道这组数的最大值和最小值，才能算出映射比例。**校准数据就是给量化工具看的"样本"，让它了解数据的分布范围。**

### 5.3 校准数据格式与生成规范

dataset.txt 的内容格式，使用 .npy 文件

关键规则：
- 每行是一个完整的样本，包含该样本的所有输入
- 文件数量 = ONNX 模型的输入数量（Encoder 为 8 个，含 `ja_bert`；Decoder 为 6 个）
- 顺序必须与 ONNX 的输入顺序一致
- 每个 `.npy` 文件的 shape 和 dtype 必须与 ONNX 输入完全匹配

> 注意：注意：ja_bert 是否出现在 ONNX 输入中，以实际导出的 ONNX 文件为准，校准数据文件数量须与之匹配。运行以下命令确认：`python -c "import onnx; m=onnx.load('encoder.onnx'); print([i.name for i in m.graph.input])"`

**为什么用 .npy 而不是 .npz？** 实测 RKNN 对 .npz 的支持不稳定，使用 .npy 文件列表更可靠。

**校准数据生成的最佳实践**：

| 规则                          | 说明                                        |
| :---------------------------- | :------------------------------------------ |
| 使用 np.random.uniform(-1, 1) | 稳定可控，不会产生 NaN                      |
| 避免 np.random.randn()        | 可能产生极端值或 NaN                        |
| 数据类型建议与 ONNX 输入一致  | 避免类型转换引入额外误差（int64 / float32） |

**为什么用均匀分布替代正态分布？**

- `np.random.randn()`：标准正态分布，可能产生极端值（如 100）甚至 NaN（数值溢出）
- `np.random.uniform(-1, 1)`：范围有界，永远稳定
- 量化校准只需要数据的 **大致分布范围**，具体数值不重要

### 5.4 量化常见错误及排查

| 错误信息                              | 原因                                       | 解决方案                                   |
| :------------------------------------ | :----------------------------------------- | :----------------------------------------- |
| `The input num: 8 not match 7`        | 校准数据文件数量与 ONNX 实际输入数量不一致 | 确认 ONNX 实际输入数量，校准数据同步调整   |
| `cannot convert float NaN to integer` | 随机数据产生 `NaN`                         | 用 `np.random.uniform(-1, 1)` 替代 `randn` |
| `Unsupport file`                      | `.npz` 格式不兼容                          | 改用 `.npy` 文件列表                       |
| `ElementwiseLogical unsupported`      | INT8 与 FP32 类型冲突                      | 使用 FP16（不加 `--do_quant`）回退         |


### 5.5 Encoder 的 INT8 量化失败：Less 算子类型冲突

**报错现象**：

```
ElementwiseLogical: unsupported A type: INT8, B type: FLOAT!
Op type:Less, name: Less:/sdp/flows.7/Less, fallback cpu failed.
```

**结合核心机制分析**：

`sdp_ratio` 是外部输入标量，在推理时被传入。Less 算子将其与图内常量进行比较。根据量化核心机制：

- 模型内部激活值被量化为 INT8，`sdp_ratio` 作为输入经过量化后变为 INT8
- 图内常量（由 sdp_ratio 参数固化而来，永远保持 FP32）
- NPU 不支持 INT8 与 FP32 混合运算

**报错的完整链路**：

```
sdp_ratio（外部输入，量化后转为 INT8）
    ↓
Less 比较算子（NPU 的 ElementwiseLogical）
    ↓
图内常量（由 sdp_ratio 参数固化而来）是图内硬编码 FP32
    ↓
❌ NPU 不支持 INT8 + FP32 混合运算
    ↓
尝试 fallback 到 CPU 执行 → 失败
    ↓
rknn_run 返回 -1
```

**为什么常见方案都无效？**

| 尝试过的方案                             | 为什么无效                                           |
| :--------------------------------------- | :--------------------------------------------------- |
| op_target={'Less': 'cpu'}                | ❌ 键必须是输出 tensor 名，不是算子类型名，写法非法   |
| op_target={'ElementwiseLogical': 'cpu'}  | ❌ 同上，写法非法                                     |
| 混合量化 custom_quantize_layers: float16 | ⚠️ 只改算子计算精度，不改变输入张量类型，冲突依然存在 |
| "标量传 FP32，其他传 INT8"               | ❌ 运行时校验 dtype 必须一致，直接拦截                |

### 5.6 为什么 Decoder 的 INT8 量化成功了？

Decoder 的输入全部是模型内部生成的同类型张量，没有引入需要与图内 FP32 常量比较的外部标量输入。因此，不会出现 INT8 与 FP32 混合运算的场景，量化可以顺利完成。

Encoder 的关键区别在于：`sdp_ratio` 是用户传入的外部标量，量化后变为 INT8，而图内常量（由 sdp_ratio 参数固化而来）是图内硬编码 FP32，两者在 Less 算子处交锋，触发了类型冲突。

## 六、动态维度踩坑（运行时）

### 6.1 经历过程

1. 基础版本：Decoder 使用**静态固定 shape RKNN 模型**，原始代码无需额外维度配置，推理正常无崩溃；
2. 切换动态 shape 模型（转换命令添加 `--seq_lens 256` 开启动态维度）后，未做任何代码适配，程序运行直接崩溃：`std::out_of_range`，报错下标为超大无符号数 `18446744073709551615`；
3. 排查排除量化因素：无论是否开启 INT8 量化，只要是动态模型就崩溃，静态模型正常，确定问题仅和动态 shape 机制相关；
4. 踩坑 1：误以为 `rknn_input` 结构体存在 `dims/n_dims` 成员直接赋值，编译报错，该结构体本身无这两个字段；
5. 踩坑 2：误用 4 参数版本 `rknn_set_input_shape` 函数，与当前 RKNN 2.3.2 SDK 头文件声明的函数签名不匹配，编译失败；
6. 查阅 SDK 标准接口，改用 `rknn_tensor_attr` 结构体传参的双参数标准 API，补充动态维度设置逻辑后，程序正常运行，崩溃消失。

### 6.2 核心问题根源

1. **RKNN 动态 shape 模型强制约束**：静态模型编译时固化张量维度，SDK 默认使用编译维度推理；**动态模型每次推理必须手动告知本轮真实输入维度**，否则 SDK 会一直使用转换模型时指定的最大序列长度（256）解析数据。
2. **未设置真实维度带来的连锁故障**：NPU 按最大长度错误解析输入张量，推理输出数据完全错乱，用于分配音频输出长度的变量 `predicted_lengths_max_real` 被算出负数；负数 int 强制转换为 `size_t` 时溢出为超大数值，访问 vector 下标触发 `std::out_of_range` 崩溃。
3. **前期两次代码方案失败原因**：
   - 方案 1：直接修改 `inputs[0].dims`：`rknn_input` 结构体不存在维度成员，语法层面编译报错；
   - 方案 2：参数 `rknn_set_input_shape`：适配高版本 RKNN API，与当前 2.3.2 SDK 接口定义不兼容。

### 6.3 最终解决方案

1. 接口适配：使用当前 RKNN 2.3.2 支持的标准动态维度 API `int rknn_set_input_shape(rknn_context ctx, rknn_tensor_attr* attr)`；
2. 推理前动态更新各输入张量维度：
   - 拷贝初始化时保存的 `app_ctx->input_attrs` 张量属性；
   - 修改 `attr` 内 `n_dims`、`dims` 为本次推理真实维度；
   - 调用 `rknn_set_input_shape` 将更新后的维度下发给 RKNN 上下文；
3. 保留原有全部输入拷贝、malloc 内存分配、推理、输出拷贝、内存释放逻辑，仅新增维度配置代码，无其他业务改动；
4. 效果：NPU 按真实有效序列长度推理，输出数值正常，`predicted_lengths_max_real` 不会出现负数，彻底解决 vector 越界崩溃，同时保留动态 shape 模型长短句自适应、提速、省内存的核心优势。

## 七、方案对比

### 7.1 各种方案对比

| 方案                  | 原理                                 | 效果                                 | 风险                       | 可行性 |
| :-------------------- | :----------------------------------- | :----------------------------------- | :------------------------- | :----- |
| 后处理裁剪 + 流式播放 | 推理完按实际帧数截断，提前播放前几帧 | 改善感知延迟                         | 无                         | ⭐⭐⭐⭐⭐  |
| INT8 量化             | 将 FP16 模型量化为 INT8              | 压缩模型体积，效果取决于算子支持程度 | 精度损失，TTS 任务音质下降 | ⭐⭐⭐    |
| 仅改 `seq_lens`       | 希望文本短就快                       | ❌ 无效（内部计算图已固化，为假动态） | 无                         | ✘      |
| 仅改 `dim_param`      | 表面修改                             | ❌ 无效（内部仍静态）                 | 无                         | ✘      |

### 7.2 推荐路径

- **推荐方案**：使用 FP16 模型（音质清晰，稳定可用），结合后处理裁剪优化感知延迟
- **备选方案**：INT8 量化（体积减小，但 TTS 任务音质下降）
- **不推荐**：继续尝试动态 shape（模型内部已固化，无法实现真动态）

### 7.3 本项目已确认的事实

| 事实                  | 说明                                                         |
| :-------------------- | :----------------------------------------------------------- |
| FP16 Decoder 可用     | 音质清晰，推理时间约 1.8–2.2s，与文本长度无关                |
| INT8 Decoder 可用     | 有声音但存在杂音，推理时间无明显改善                         |
| Encoder INT8 量化失败 | `Less` 算子 INT8/FP32 类型冲突，无法解决                     |
| 动态 shape 无效       | ONNX 导出时 Tracing 机制已固化，`dynamic_axes` 仅为元数据标记 |
| 校准数据              | 必须来自真实推理，随机数校准无效                             |

### 7.4 结论

若必须使用 MeloTTS：接受当前延迟（1.8–2.2s），通过预加载、缓存、后处理播放等工程手段优化用户体验。

若可换模型：本项目未实测其他 TTS 架构，需自行移植并测试，无法提供延迟数据。

## 八、最终总结

### 8.1 最终方案与模型组合

**本项目建设使用的模型**
| 模型    | 方案                 | 说明                                              |
| :------ | :------------------- | :------------------------------------------------ |
| Encoder | FP16 静态            | 固定 256 帧，不加 `--do_quant`                    |
| Decoder | FP16 固定长度（256） | 保留 `dim_param` 标记（元数据动态），但内部已固化 |

推理时的工作方式：
1. 输入文本 → padding 到 256 帧（无论文本多短，都补齐到 256）
2. Encoder（FP16）→ 输出特征
3. Decoder（FP16）→ 生成音频（固定 512 帧）

推理时间与文本长度无关，固定为 1.8–2.2 秒。这是架构决定的，不是转换能解决的。

量化结果：
| 模型         | 量化结果       | 说明                                                     |
| :----------- | :------------- | :------------------------------------------------------- |
| Encoder INT8 | ❌ 失败         | `Less` 算子 INT8/FP32 类型冲突，无法解决                 |
| Decoder INT8 | ✅ 体积压缩成功 | 从 129MB 压缩至 67MB，有声音但杂音重，推理时间无明显改善 |

完成状态：
| 组件                   | 状态                            |
| :--------------------- | :------------------------------ |
| Encoder → RKNN（FP16） | ✅ 转换成功，音质正常            |
| Decoder → RKNN（FP16） | ✅ 转换成功，音质清晰            |
| Decoder → RKNN（INT8） | ✅ 转换成功，有声音但杂音重      |
| Encoder → RKNN（INT8） | ❌ 量化失败，`Less` 算子类型冲突 |
> 本项目建设使用 FP16 全套方案。 INT8 Decoder 虽有体积优势，但音质下降明显，且推理时间无明显改善，不作为生产推荐。

### 8.2 常见错误速查

| 错误信息                                  | 根本原因                                      |
| :---------------------------------------- | :-------------------------------------------- |
| invalid expand shape                      | Expand 操作的目标形状包含 dim_param           |
| MatMul dimension mismatch                 | dynamic_input 中某个形状配置错误              |
| The input num not match                   | 校准数据的文件数量不对（8 vs 7）              |
| cannot convert float NaN                  | 校准数据里出现了 NaN                          |
| ElementwiseLogical unsupported            | INT8 与 FP32 类型冲突                         |
| std::out_of_range（18446744073709551615） | 动态模型未设置真实维度，负数溢出为超大 size_t |

### 8.3 核心认知

1. MeloTTS 是音质优先模型，不是速度优先。1.8–2.2 秒的推理时间是架构决定的常态。
2. 量化（INT8）的主要价值是压缩体积（129MB→67MB），对推理时间提升有限。
3. `dynamic_axes` + `seq_lens` 在当前导出方式下是"纸面动态"。
4. `torch.jit.trace` 是假动态的根源，因它固化所有 shape 相关值。
5. Less 算子报错的根本原因是：量化后模型内部的激活值为 INT8，而图内常量节点（由 sdp_ratio 参数固化而来）保持 FP32，NPU 不支持 INT8 与 FP32 的混合运算，导致 Less 算子无法在 NPU 上执行。
6. 最有效的优化路径是后处理裁剪 + 流式播放——零模型改动，大幅改善感知延迟。
7. 不要与非自回归架构死磕低延迟——选型错误比技术问题更致命。如果需 <500ms 延迟，应评估 FastSpeech2 等自回归 TTS。
8. FP16 是 INT8 的安全替代方案：不需要校准数据，不会出现类型冲突，稳定可用。

### 8.4 关键文件与工具

| 文件/工具                    | 说明                                                       |
| :--------------------------- | :--------------------------------------------------------- |
| melo/api.py                  | 修改后的 export_onnx 函数（包含 dynamic_axes 和常量折叠）  |
| convert_dynamic.py           | 动态 RKNN 转换脚本（硬编码形状规则，支持 encoder/decoder） |
| generate_calibration_data.py | 生成量化校准数据（.npy 文件）                              |
| dataset.txt                  | 量化时指向校准数据文件的索引                               |
| encoder-ZH_MIX_EN.onnx       | 动态 ONNX 模型（8 个输入，包含 ja_bert）                   |
| decoder-ZH_MIX_EN.onnx       | 动态 ONNX 模型（6 个输入）                                 |
| decoder-ZH_MIX_EN.rknn       | 成功转换的动态 RKNN 模型                                   |

**遇到过的主要坑：**

| 坑                      | 本质                                                         |
| :---------------------- | :----------------------------------------------------------- |
| `ja_bert` 输入数量变化  | 取决于 ONNX 导出时日语模块是否有效参与计算，以实际导出的 ONNX 输入列表为准。校准数据文件数量须与之匹配 |
| `Expand` 报错           | 目标形状含 `dim_param` 动态占位符，RKNN 常量折叠无法确定具体形状。开启 `do_constant_folding=True` 可将其折叠为具体值 |
| `ScatterND` 报错        | Encoder 内部 SDP 模块用 `ScatterND + Slice` 构造形状，其中 `-1` 无法被 RKNN 常量折叠消除，导致动态转换失败，Encoder 最终采用静态方案 |
| 多长度 Decoder 失败     | RKNN 动态 shape 是“预设菜单”模式，多长度预设导致形状推断出错，锁定单长度 `seq_lens=256` 解决 |
| 校准数据 `NaN`          | `np.random.randn()` 可能产生极端值或 `NaN`，改用 `np.random.uniform(-1, 1)` 替代 |
| 量化 `input num` 不匹配 | 校准数据文件数量与 ONNX 实际输入数量不一致                   |

确认 ONNX 实际输入数量的命令如下：
```
python -c "import onnx; m=onnx.load('model.onnx'); print([i.name for i in m.graph.input])"
```

### 8.5 可迁移通用技能 🟢

#### ONNX 导出通用技能

| 参数                        | 通用知识点                                                   |
| :-------------------------- | :----------------------------------------------------------- |
| opset_version               | opset 版本决定可用算子集合，版本 16 对动态形状支持更好。不是越高越好——需平衡算子支持度和稳定性 |
| do_constant_folding         | 开启后会将所有输入为常量的子图提前计算结果。副作用：可能导致输入被移除（如全零张量），需在后续流程中适配 |
| keep_initializers_as_inputs | 与 do_constant_folding 配合使用。设为 False 会将常量从输入列表中移除，影响后续 graph.input 数量 |
| dynamic_axes                | 声明哪些维度是动态的。关键认知：这只是元数据声明，不保证内部计算图真的支持动态变化 |

**ONNX 模型结构理解**：

- `dim_value` vs `dim_param`：`dim_value` 是固定值，`dim_param` 是动态占位符。两者共存是正常的。
- 未命名的 `dim_param`（如 `Addlogw_dim_0`）会导致 RKNN 形状推断失败。必须为所有动态维度明确命名。
- `graph.input` 与 `graph.output`：用 `onnx.load()` 查看模型输入输出，是排查问题的基本功。

**验证真动态的方法**：不要相信 `dim_param` 的"纸面声明"，必须用 ONNX Runtime 实际推理验证。

#### RKNN 转换通用技能

- **核心认知**：RKNN 不支持完全自由的动态维度，必须在转换时通过 `dynamic_input` 列出所有可能用到的形状组合。
- **通用建议**：先用一个长度验证可行性，再逐步扩展。
- **optimization_level**：取值范围 0–3。设 0 关闭优化，排除干扰，适合调试。先设 0 确认模型能转，再逐步提高。
- **op_target 通用规则**：键必须是输出 tensor 名，不是算子类型名。需要什么名称，用 `onnx.load()` + 打印节点信息确认。

#### INT8 量化通用技能

- 量化核心机制适用于所有 RKNN PTQ 量化，不仅限于 MeloTTS。
- 校准数据决定量化成败：必须精确匹配 ONNX 输入的数量、顺序、形状、数据类型。
- 排查方法：`python -c "import numpy as np; data=np.load('sample.npy'); print(data.shape, data.dtype)"`

#### 调试方法论

| 工具                  | 用途                                  | 通用性           |
| :-------------------- | :------------------------------------ | :--------------- |
| **Netron**            | 可视化模型结构，查看输入输出形状      | 🟢 所有模型       |
| **ONNX Runtime**      | 验证 ONNX 模型是否能正确推理          | 🟢 所有模型       |
| onnx.load() + print() | 查看模型元数据（输入/输出名称、形状） | 🟢 所有模型       |
| rknn-toolkit2 日志    | 查看量化详情、算子回退信息            | 🟢 所有 RKNN 项目 |

**模型分析通用命令**：

```
# 查看输入输出
python -c "import onnx; m=onnx.load('model.onnx'); print([i.name for i in m.graph.input])"
python -c "import onnx; m=onnx.load('model.onnx'); print(m.graph.output[0])"

# 查看特定算子节点
python -c "import onnx; m=onnx.load('model.onnx'); [print(n.name) for n in m.graph.node if n.op_type=='MatMul']"
```

**二分法定位问题**：

1. 先用单长度（静态）验证模型能否转换
2. 再尝试多长度（动态）逐步扩展
3. 关闭量化先验证浮点模型 → 再尝试量化

**通用工作流模板**：

```
1. 导出 ONNX
   ├── 正确设置 opset_version
   ├── 声明 dynamic_axes（所有动态维度命名）
   └── 验证 ONNX 可用（ONNX Runtime 推理）

2. 转换 RKNN
   ├── 先用单长度浮点验证
   ├── 再尝试多长度浮点
   └── 最后尝试量化（可能需要回退到 FP16）

3. 量化调试
   ├── 检查校准数据（数量、顺序、dtype）
   ├── 排查算子回退
   └── 必要时放弃 INT8，使用 FP16
```

### 8.6 MeloTTS 特有知识（不可迁移）

以下知识**仅适用于本 MeloTTS 项目**，不通用：

| 知识                               | 说明                                                         |
| :--------------------------------- | :----------------------------------------------------------- |
| `y_lengths = 2 * x_length` 硬编码  | 硬编码的默认值。若改为动态计算（如 `torch.sum(w_ceil)`），ONNX 导出会引入 `ScatterND` 等不易被 RKNN 转换的算子，转换失败风险较高 |
| `ja_bert` 输入数量变化             | `ja_bert` 是否出现在 ONNX 输入中，以实际导出的 ONNX 为准，校准数据文件数量须与之匹配 |
| `mmontol/MeloTTS` 仓库             | 社区修改版，在官方仓库基础上增加了 ONNX 导出功能，非官方仓库 |
| `Less` 算子与 `sdp_ratio` 类型冲突 | INT8 量化时外部输入 `sdp_ratio` 强制转为 INT8，而阈值常量（如 0.2）为图内 FP32 常量，NPU 不支持混合类型逻辑比较。非模型设计缺陷，是 RKNN PTQ 量化规则的固有限制 |
| Decoder 循环次数固定 4 层          | VITS 架构的流式生成设计，`n_flows` 固定为 4 层。可通过修改源码减少层数，但音质会明显下降且 RKNN 转换成功率不确定 |
| 输出长度固定 `[1,1,262144]`        | ONNX 导出时 Tracing 机制将 `y_lengths` 固化为常量 `2 * x_length`（512），对应音频长度 `512 * 512 = 262144`。`dynamic_axes` 仅为元数据标记，无法改变已固化的计算图 |
| `MeCab` + `unidic` 依赖            | MeloTTS 多语言支持需要日语分词器和词典，`pip install unidic-lite` 可解决，非模型设计问题 |


### 8.7 关键术语

| 术语                | 解释                                                         |
| :------------------ | :----------------------------------------------------------- |
| **ONNX**            | 开放神经网络交换格式，是 PyTorch、TensorFlow 等框架导出模型的通用标准格式，作为 PyTorch 到 RKNN 的中间桥梁 |
| **RKNN**            | Rockchip 为 NPU 平台定义的专有模型格式（`.rknn`），在 RK3588、RK3566 等设备上利用 NPU 硬件加速推理 |
| **`dim_value`**     | ONNX 张量形状描述中的固定值，表示该维度被固化为一个确定的整数，运行时不可变。如 `dim_value: 1` 表示该维度永远为 1 |
| **`dim_param`**     | ONNX 张量形状描述中的符号占位符（symbolic dimension），以字符串命名表示该维度理论上可变化。如 `dim_param: "seq_len"`。但该标记仅影响 ONNX I/O 节点的形状声明，不改变内部计算图，若内部已被 Tracing 固化则无效 |
| **`dynamic_axes`**  | PyTorch 导出 ONNX 时的参数，用于声明模型输入/输出中哪些维度是动态的，会为 I/O 节点生成 `dim_param` 标记。如 `{"x": {1: "seq_len"}}` 表示 `x` 的第 2 维可在推理时变化 |
| **常量折叠**        | 图优化技术，静态计算仅依赖于常量初始化表达式的图的部分，在编译时提前算出结果，消除运行时计算的需要。例如 `y_lengths = 2 * x_length`，若 `x_length` 是常量 256，则 `y_lengths` 被折叠为常量 512 |
| **`onnxsim`**       | ONNX 模型简化工具，通过常量折叠、冗余节点消除、算子融合等方式优化 ONNX 模型，可能将 `dim_param` 固化为 `dim_value` |
| **`dynamic_input`** | RKNN 转换时的参数，用于配置模型支持动态形状输入。RKNN 需要在转换时列出所有可能用到的形状组合（预设菜单模式），NPU 为每种组合生成优化指令，推理时从预设中选择 |
| **INT8 量化**       | 将模型权重和激活从 FP32 映射到 INT8，体积可缩小至 FP32 的 1/4（减少 75%），推理速度提升 3-5 倍，精度损失可控 |
| **FP16 量化**       | 将模型从 FP32 转换为 FP16（半精度浮点数），体积减小约 50%，精度损失几乎可忽略 |
| **校准数据**        | INT8 量化时用于统计模型各层激活值分布的数据集，量化工具据此计算 scale（缩放因子）和 zero_point（零点），决定 FP32 到 INT8 的映射方式。校准数据必须来自真实推理场景，随机数校准可通过 build 但模型输出异常 |
| **`dataset.txt`**   | RKNN 量化时校准数据的索引文件，每行一个完整样本，包含该样本所有输入张量的 `.npy` 文件路径。文件数量必须与 ONNX 模型输入数量一致，顺序必须与 `graph.input` 顺序一致 |
| **`MatMul`**        | 矩阵乘法，深度学习中最基础的计算操作之一。TTS 模型中大量存在，对张量形状敏感，多长度动态 shape 下易触发 `dimension mismatch` 错误 |
| **`ScatterND`**     | ONNX 算子，根据索引将更新值写入张量指定位置。MeloTTS Encoder 的 SDP 模块使用该算子构造形状，其输出形状依赖动态索引，是 Encoder 动态转换失败的原因之一 |
| **`Expand`**        | ONNX 算子，将张量广播到目标形状。当目标形状包含 `dim_param` 时，RKNN 常量折叠无法确定具体形状，报 `invalid expand shape`。开启 `do_constant_folding=True` 可将其折叠为具体值 |
| **SDP**             | Stochastic Duration Predictor（随机时长预测器），MeloTTS Encoder 内部模块，用于预测每个音素的发音时长。该模块使用 `ScatterND` 和 `Slice` 构造形状，是 Encoder 动态转换失败的主要原因 |


### 仓库链接

- MeloTTS：https://github.com/kyshipit/MeloTTS
- [MeloTTS RKNN 量化部署踩坑记录](https://github.com/kyshipit/tech-notes/blob/main/deploy/melotts-rknn量化部署踩坑记录.md)：https://github.com/kyshipit/tech-notes