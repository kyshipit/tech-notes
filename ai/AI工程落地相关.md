<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# AI工程落地相关

# 第一部分：AI整体认知框架

## 1\.1 全链路串联逻辑

**核心链路：模型（大脑）→ 量化/蒸馏/剪枝（轻量化适配）→ Agent（自主决策手脚）→ Skill（领域工具能力包）→ RTK/DCP（Token成本优化）**

**完整落地流程**：

1. **基座获取**：训练或开源获取通用大模型（LLaMA、GPT、Claude等），具备基础推理与知识能力。

2. **模型轻量化**：通过量化、蒸馏、剪枝三大技术，压缩模型体积、降低算力消耗，适配云端/边缘设备部署。

3. **Agent工程化**：将轻量化模型封装为智能Agent（OpenCode、Cursor、Claude Code），赋予自主规划、任务拆解、工具调用能力。

4. **领域能力赋能**：为Agent配置标准化Skills技能包，落地垂直场景（代码审查、UX设计、工程开发等）。

5. **效率成本优化**：通过RTK、DCP等工具优化Token消耗，压缩上下文冗余，大幅降低推理成本、提升响应速度。

## 1\.2 LLM\+Agent组合本质

### 核心结论

AI工具落地效果由**模型基座能力**\+**Agent工程实现**双向决定，二者缺一不可。所有Agent能力、智能交互、工具调用，本质均为**上下文文本驱动的Token概率预测**，无额外黑盒逻辑。

### 全能力统一底层：一切皆上下文

所有AI高阶能力，最终都会转化为文本，塞入LLM上下文窗口，由“预测下一个Token”模型统一推理：

- **思维链CoT**：模型在上下文内生成的“自我思考草稿”，辅助分步推理。

- **Tool Use/MCP工具调用**：上下文预存工具描述、入参规范，模型输出调用指令，工具执行结果追加回上下文，形成闭环。

- **Agent循环**：持续迭代「思考\-调用工具\-获取结果\-追加上下文」的循环流程。

- **Skills技能包**：领域操作手册、场景规范文本，按需加载至上下文。

- **RAG检索增强**：外部知识库检索的片段文本，拼接进上下文辅助推理。

- **记忆系统**：沉淀跨会话有效信息，新会话启动时自动加载至上下文，实现“长期记忆”。

### 渐进式披露的核心价值

模型原生能力固定，**上下文的信息质量、数量、组织方式**直接决定Agent上限。从Function Calling→MCP→Skills→渐进式披露，所有技术迭代的核心目标一致：**在有限上下文窗口内，高效组织信息，规避Token爆炸与信息淹没，最大化释放模型推理能力**。

## 1\.3 上下文与Token底层机制

### 1\.3\.1 上下文定义

上下文本质是 **messages数组**，所有发给LLM的输入统称为Prompt，messages数组是Prompt的唯一载体。

### 1\.3\.2 Token基础规则

Token是LLM处理文本的最小单位：英文常用单词约1Token，单个汉字约1\-2Token。Token数量直接决定推理耗时、计费成本、上下文占用。

|请求内容|messages条数|prompt\_tokens|
|---|---|---|
|仅发送“你好”|1条|5|
|仅发送“我叫什么？”|1条|7|
|携带完整对话历史提问“我叫什么？”|5条|63|

核心规律：对话历史越长，messages数组越大，prompt\_tokens越高，成本越高、延迟越高。

### 1\.3\.3 模型无状态核心特性

LLM API调用**完全无状态**，每次请求相互独立，模型不会自动留存任何会话记忆。

多轮对话的本质：每次API请求，**手动携带完整历史对话messages**。市面上所有AI对话、AI编程工具，底层均基于该逻辑，仅上层封装了上下文压缩、冗余过滤、历史裁剪等优化策略。

# 第二部分：量化部署原理

## 2\.1 深度学习

### 2\.1\.1 张量

张量是深度学习唯一数据载体，本质为多维数组，模型输入、网络权重、中间特征、推理输出全部为张量。包含0维单值、1维向量、2维矩阵、3/4维批量特征图。

**输出张量**：网络各层运算后输出的特征数据，是量化校准、精度校验、张量统计的核心对象。

**张量分布**：张量数值的统计规律（均值、方差、最值、分布形态），量化的核心目标是**最大限度保留量化前后张量分布一致性**，避免精度畸变。

### 2\.1\.2 余弦相似度

取值范围\[\-1,1\]，衡量张量/特征向量重合度：越接近1，量化前后特征一致性越高、掉点越少；数值越低，特征畸变越严重、推理精度越差。是RKNN嵌入式量化部署的核心校验指标。

### 2\.1\.3 浮点/定点数区别

- **浮点型FP**：小数点浮动，范围大、精度高；常用FP32、FP16、BF16；PyTorch/ONNX模型默认FP32全精度。

- **定点型**：小数点固定，硬件仅存储整数，依靠scale映射小数；常用INT8、INT4；边缘NPU量化推理专用格式。

## 2\.2 主流网络架构区别

### 2\.2\.1 CNN卷积神经网络

专注视觉任务（YOLO、ResNet、MobileNet），核心四层结构：

- **卷积层Conv**：分层提取图像特征（浅层纹理、中层形状、深层轮廓）。

- **BN批量归一化**：规整张量分布，防止数值爆炸/消失，提升量化稳定性。

- **激活层**：引入非线性，让模型学习复杂视觉特征。

- **池化层**：降维减算力，保留核心特征，压缩特征图尺寸。

### 2\.2\.2 CNN vs Transformer差异

|对比维度|CNN|Transformer|
|---|---|---|
|感受野|局部滑窗，需堆叠多层扩视野|全局感受野，单层覆盖全图|
|权重共享|支持，参数量小|不支持，参数量大|
|算力消耗|低|高|
|张量分布|稳定|波动大|
|量化友好度|极佳，适配边缘NPU|较差，易掉精度，校准要求高|

ViT/Transformer无卷积、池化层，核心为多头自注意力\+层归一化\+前馈网络。

## 2\.3 模型量化

### 2\.3\.1 量化本质

将FP32浮点张量转为INT8/INT4定点整数存储推理，实现：减小模型体积、节省内存、提升NPU推理速度、适配边缘硬件。

### 2\.3\.2 量化粒度

- **粗粒度Per\-Tensor**：整张量共用一套scale/zero\_point，速度快、精度差。

- **细粒度Per\-Channel**：单通道独立统计最值、独立量化参数，误差小、精度高，为RKNN工业部署标配。

### 2\.3\.3 核心量化参数

- **scale缩放因子**：浮点与定点换算刻度，整型\+1对应的浮点增量；scale越大，量化精度越粗糙。

- **zero\_point零点**：浮点0对应的整型位置，用于平移数值区间，适配无符号整数存储负数，由张量最值唯一计算，不可手动篡改。

### 2\.3\.4 RKNN量化校准逻辑

必须通过真实校准集执行FP32无损推理，获取每一层、每通道张量最值（min/max），方可计算合法scale与zero\_point；无真实数据校准会导致量化参数失效、模型精度崩盘。

## 2\.4 张量内存排布格式

- **NCHW（训练框架默认）**：批次\-通道\-高度\-宽度，PyTorch/ONNX原生格式，按通道整图存储。

- **NHWC（硬件原生）**：批次\-高度\-宽度\-通道，RKNN/NPU/安卓硬件原生支持，像素连续存储，内存读取效率更高、推理更快。

适配方案：RKNN\-Toolkit2自动完成NCHW→NHWC转换，无需手动改代码。

## 2\.5 RKNN核心内存对象

- **rknn\_context上下文句柄**：模型与NPU全局管理器，存储模型地址、硬件状态、张量内存、推理配置，所有API依赖此句柄。

- **rknn\_tensor\_attr张量属性结构体**：存储张量shape、数据类型、量化参数、内存格式，用于指导预处理、反量化、缓冲区申请。

张量内存分为：属性配置内存、真实数据缓冲区内存。

## 2\.6 RKNN Runtime C API 标准生命周期（不可逆）

工程固定调用流程，所有嵌入式RK部署统一遵循：

1. **rknn\_init**：加载模型、初始化NPU、创建上下文、申请硬件资源。

2. **rknn\_query（第一次）**：查询模型基础信息、输入输出shape、数量。

3. **rknn\_query（第二次）**：查询张量详细属性、量化参数、内存格式。

4. **rknn\_inputs\_set**：绑定预处理后的NHWC格式输入数据。

5. **rknn\_run**：下发推理任务，NPU执行前向计算。

6. **rknn\_outputs\_get**：读取NPU推理结果，用于后处理、反量化。

7. **rknn\_destroy**：释放资源、销毁上下文，杜绝内存泄漏。

# 第三部分：AI工具链实操

## 3\.1 模型优化

|优化技术|核心原理|是否改结构|是否重训练|核心收益|
|---|---|---|---|---|
|量化|FP32→INT8/INT4精度压缩|否|无需（后训练量化）|体积\-75%，速度提升3\-5倍|
|剪枝|删除冗余权重/神经元|是|可选微调|大幅降低FLOPs计算量|
|蒸馏|大模型教小模型，迁移能力|是|需要完整训练|小模型逼近大模型推理效果|

PyTorch→ONNX→RKNN部署链路中：量化为**必选核心环节**，剪枝、蒸馏为前置可选优化。

### 模型工作链路

1. **研发训练**：架构设计、大规模预训练（如70B LLaMA）。

2. **优化压缩**：蒸馏、剪枝、量化、微调，轻量化模型。

3. **转换部署**：ONNX格式转换、引擎适配（RKNN/TensorRT）、服务化/边缘部署。

## 3\.2 Agent智能体

Agent是LLM的应用层载体，为模型赋予执行能力。核心闭环：**理解自然语言目标→自主任务拆解→工具链式调用→闭环完成任务**。

## 3\.3 Token优化工具（RTK/DCP/插件）

### 3\.3\.1 工具定位与收益

|工具|类型|核心作用|Token节省比例|
|---|---|---|---|
|RTK|CLI中间件二进制|命令输出过滤精简|60%\-90%|
|DCP|对话插件|上下文动态剪枝|30%\-50%|
|UltraPress|压缩插件|四层综合文本压缩|30%\-70%|
|ACP|去重插件|上下文自动去重|约50%|

核心区分：RTK/DCP为**效率优化工具**，Skills为**领域能力模板**，三者协同、互不替代。

### 3\.3\.2 工具安装脚本

```Plain Text
# 安装RTK
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
rtk init -g --opencode

# 安装DCP（长会话优化必备）
npm i -g @tarquinen/opencode-dcp
```

## 3\.4 Agent Skills技能

### 3\.4\.1 核心定义

2025年官方开放标准，基于**渐进式披露**机制：优先加载技能元数据，任务匹配后再加载完整指令，避免上下文冗余。单Skill为独立文件夹，核心包含 **SKILL\.md**（必填）\+ 可选scripts脚本。

### 3\.4\.2 技能安装与开发

快速安装：支持Cursor/OpenCode/Codex多代理统一指令

```Plain Text
# 通用安装示例
npx skills add ByteRax/guodegang-skills --agent opencode -g

# 自定义开发Skill
# 1.新建技能文件夹 2.编写SKILL.md核心规则 3.可选添加脚本 4.npx skills init初始化测试
```

### 3\.4\.3 优质技能选型

- 新手入门：Systematic（全流程）、Supercoder（TDD开发）

- 前端/产品：ux\-toolkit（UX设计\+审查）

- Token优化：preload\-skills（按需加载、预算管控）

- 自建生态：skill\-creator（技能脚手架）、skill\-manager（RTK集成\+持久记忆）

## 3\.5 ONNX模型维度验证

### 3\.5\.1 四层验证维度

1. **结构层（Netron可视化）**：快速比对网络拓扑、算子分布，适合定性检查。

2. **算子层（Python脚本）**：精准提取算子类型、属性、序列，校验模型骨架一致性。

3. **权重层（余弦相似度）**：量化权重偏差，判定量化/转换精度损耗。

4. **逻辑层（ONNX Runtime）**：输入统一数据比对输出，验证功能完全等价。

### 3\.5\.2 验证代码


```Plain Text
import onnx
from onnx import helper

def extract_ops_info(model_path):
    model = onnx.load(model_path)
    ops = []
    for node in model.graph.node:
        op_info = {
            'name': node.name,
            'op_type': node.op_type,
            'input': list(node.input),
            'output': list(node.output),
            'attributes': {}
        }
        for attr in node.attribute:
            op_info['attributes'][attr.name] = helper.get_attribute_value(attr)
        ops.append(op_info)
    return ops

# 调用示例
your_ops = extract_ops_info('your_model.onnx')
official_ops = extract_ops_info('official_model.onnx')
print(f"当前模型算子数: {len(your_ops)} | 官方模型算子数: {len(official_ops)}")
```

```Plain Text
import onnx
from onnx import numpy_helper
import numpy as np

def load_weights(model_path):
    model = onnx.load(model_path)
    weights = {}
    for initializer in model.graph.initializer:
        weights[initializer.name] = numpy_helper.to_array(initializer)
    return weights

your_weights = load_weights('your_model.onnx')
official_weights = load_weights('official_model.onnx')

for name in your_weights:
    if name in official_weights:
        w1 = your_weights[name].flatten()
        w2 = official_weights[name].flatten()
        cos_sim = np.dot(w1, w2) / (np.linalg.norm(w1) * np.linalg.norm(w2))
        if cos_sim < 0.9999:
            print(f"权重异常: {name} 余弦相似度={cos_sim:.6f}")
        else:
            print(f"权重正常: {name}")
```

```Plain Text
import onnxruntime as ort
import numpy as np

def compare_outputs(model_a_path, model_b_path):
    sess_a = ort.InferenceSession(model_a_path)
    sess_b = ort.InferenceSession(model_b_path)

    input_name = sess_a.get_inputs()[0].name
    input_shape = sess_a.get_inputs()[0].shape
    input_shape = [d if isinstance(d, int) else 1 for d in input_shape]
    dummy_input = np.random.randn(*input_shape).astype(np.float32)

    out_a = sess_a.run(None, {input_name: dummy_input})
    out_b = sess_b.run(None, {input_name: dummy_input})

    for idx, (oa, ob) in enumerate(zip(out_a, out_b)):
        if np.allclose(oa, ob, rtol=1e-4, atol=1e-6):
            print(f"输出{idx}: 完全匹配")
        else:
            print(f"输出{idx}: 误差超标，最大偏差={np.max(np.abs(oa-ob))}")

compare_outputs('your_model.onnx', 'official_model.onnx')
```

### 3\.5\.3 验证结论

算子\+属性一致 = 模型骨架一致；权重高相似度 = 精度无损；输出完全匹配 = **功能完全等价，可直接替换部署**。

## 3\.6 模型部署路线

PyTorch原生模型 → 结构理解 \& 预处理适配 → ONNX导出 \& 化简 → ONNX精度验证 → 平台引擎转换（RKNN/TensorRT/OpenVINO）→ 嵌入式推理开发 → 量化优化 \& 性能调优

# 第四部分：开发环境与调试

## 4\.1 Conda环境管理

### 4\.1\.1 快速安装

```Plain Text
curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
```

### 4\.1\.2 命令

|功能|命令|
|---|---|
|创建环境|conda create \-n myenv python=3\.11|
|激活/退出环境|conda activate myenv / conda deactivate|
|查看/删除环境|conda env list / conda remove \-n myenv \-\-all|
|环境导出/恢复|conda env export \> env\.yml / conda env create \-f env\.yml|

## 4\.2 CUDA版本

- **nvidia\-smi**：查询显卡驱动支持的最高CUDA版本（上限）。

- **nvcc \-V**：系统已安装的CUDA Toolkit版本（开发基准）。

- **PyTorch CUDA**：预编译包自带CUDA运行时，不依赖系统Toolkit。

核心原则：高版本驱动向下兼容低版本CUDA，安装PyTorch以nvcc版本为准。

## 4\.3 YOLO部署环境

Conda环境专属安装：torch、torchvision、ultralytics、onnx、onnxruntime、timm、netron。

系统全局安装：curl、git、ffmpeg等系统工具。

## 4\.4 Ultralytics设备对齐报错解决方案

问题：手动创建CPU张量与GPU模型设备不匹配，触发类型报错。

解决方案：输入张量执行 `tensor.to(device)` 对齐设备；或直接使用高层model\(\)接口（自动预处理\+设备对齐）。

## 4\.5 PyTorch与TorchVision版本对应

精准安装CUDA版本torchvision：

```Plain Text
pip install torchvision==0.19.0 --index-url https://download.pytorch.org/whl/cu121
```

# 附录：工具与平台

- **数据处理**：Numpy、Pandas、Statsmodels

- **可视化**：Matplotlib、Seaborn、PIL

- **计算机视觉**：OpenCV、Dlib

- **深度学习框架**：PyTorch、TensorFlow

- **嵌入式部署**：RKNN Toolkit、TensorRT、OpenVINO
