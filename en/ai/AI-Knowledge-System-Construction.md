**English** | [简体中文](../../ai/AI知识体系构造.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# AI Knowledge System Construction

## Overview

### Core storyline

The ultimate goal of the entire AI field is to build industrial-grade intelligent agents that can solve real-world problems.

- All the underlying technologies (mathematics, machine learning, deep learning, large models) are designed to create the "brain" of the agent.
- All engineering techniques (model engineering + agent engineering) are designed to enable agents to run at low cost, high efficiency, and securely.
- All security and ethical issues are inevitable problems that arise after agents are deployed on a large scale.

🧠 Core understanding: The Large Model (LLM) is merely the "brain" of the agent, not the agent itself. Agent = Brain + Memory + Planning + Tools + Skills.

### End-to-End Module Division of Labor Summary Table

Module | Core Responsibilities | Boundary crossing behaviors to be avoided | Core tools/standards | Project Mapping
:-- | :-- | :-- | :-- | :--
Brain (large model) | Decision making, language generation, logical reasoning | It should not be used as a database (it cannot remember precise facts); it should not directly execute low-level system actions. | GPT, LLaMA, Qwen | RKLLM / llama.cpp / Cloud API
Memory module | Managing short-term context, long-term vector memory, skill usage records, and dynamic loading and unloading. | It does not perform causal logical reasoning or content generation, but vector retrieval itself includes similarity calculation. | Chroma, Pinecone, Supermemory | LlamaIndex + Chromadb
Planning module | Task breakdown, step orchestration, execution status management, failure rollback, reflection and correction, and multi-skill combination orchestration. | Do not directly execute shell commands or APIs; do not only perform two-phase planning (a reflection phase is mandatory). | ReAct, Reflexion, LangGraph | LangGraph / CrewAI / Self-written loop
Tool call | Execute a single external action (API/CLI/database) | It does not make high-level task decisions (such as "what to do next"); it allows execution-level local decisions (such as timeout retries). | REST API, CLI, SQL | MCP protocol / hardware driver functions
Skills | Provides professional workflows, best practices, and error handling templates. | Do not schedule tasks across tasks; do not make global decisions beyond your authority. | Skills Open Standard | SKILL.md
RAG Search | Provide factual knowledge and documentation. | No content is generated; no logical reasoning is performed. | LlamaIndex, Chroma | —
Bionic Algorithm | Prerequisite parameters/structure optimization | It does not participate in the pre-training of large models (except for evolutionary strategies, which can be used to train reinforcement learning policy networks); it does not participate in inference. | GA, PSO, Optuna | —
Model Engineering | Optimize model computation | It does not change the input/output format or dimensions; it will change the weight precision and numerical distribution. | Quantification, pruning, distillation, ONNX→RKNN | —
Agent Engineering | Optimize input/output data volume/Token cost and task flow reliability | Without changing the model itself | Context trimming, on-demand memory loading, CLI output filtering, etc. | —

🧠 Core Principle: To help establish a systems perspective, the responsibilities of each module can be ideally separated—the large model does not replace the database (it stores fuzzy parametric knowledge, not precise factual records), the memory module focuses on retrieval (vector retrieval itself includes similarity calculation), the planning module leads task decomposition (but in modes like ReAct, it can directly initiate tool calls), and the tools do not make high-level decisions. Reasonable local overlap is permissible in actual engineering, but the overall responsibilities must remain clear.

## I. Underlying Mathematical and Tool Foundations

### 1.1 Essential Mathematical Foundations

#### 1.1.1 Linear Algebra

Core principle: The computational essence of all AI models is a linear transformation of tensors (multidimensional arrays). After the input data is converted into tensors, feature extraction and prediction are completed through operations such as matrix multiplication and addition.

Key concepts:

- Tensors: scalar (0-dimensional), vector (1-dimensional), matrix (2-dimensional), high-dimensional tensors (3-dimensional and above, such as images and videos).
- Matrix multiplication: The core operation in neural networks involving weights and input features, achieving a linear combination of features.

🧠 Core understanding: Linear algebra is the "arithmetic language" of AI, and all models' underlying calculations are based on tensor operations.

#### 1.1.2 Calculus

Core principle: The rate of change of the function is calculated using derivatives and partial derivatives, providing direction for updating model weights.

Key concepts:

- Derivative: the rate of change of a single-variable function
- Partial derivative: The rate of change of a multivariable function with respect to a particular variable.
- Gradient: A vector consisting of all partial derivatives of a multivariable function, pointing in the direction of the fastest increase in the function value.
- The chain rule: a method for finding the derivative of a composite function, is the mathematical foundation of the backpropagation algorithm.

🧠 Core understanding: The gradient is the direction in which the loss function changes the fastest; gradient descent is the fine-tuning of weights along the opposite direction of the gradient, and it is the core method for training the main body of deep learning models.

#### 1.1.3 Probability and Statistics

Core principle: Use probability distributions to describe the uncertainty of data, and use methods such as maximum likelihood estimation to make the model fit the data distribution.

Key concepts:

- Probability distribution: describes the probability patterns of a random variable's values ​​(such as normal distribution, Bernoulli distribution).
- Maximum likelihood estimation: Finding the model parameters that maximize the probability of the observed data occurring.
- Bayes' theorem describes the relationship between conditional probabilities and is the foundation of Bayesian machine learning.

#### 1.1.4 Information Theory

Core principle: Use entropy to quantify the uncertainty of information, and use cross-entropy to measure the difference between model predictions and true labels.

Key concepts:

- Entropy: Describes the degree of uncertainty of a random variable; the higher the entropy, the higher the uncertainty.
- Cross-entropy: Measures the difference between two probability distributions and is the most commonly used loss function for classification tasks.

🧠 Core understanding: Cross-entropy loss function is the standard loss function for deep learning classification tasks.

### 1.2 Core Tool Ecosystem

category | tool | use
:-- | :-- | :--
Deep learning framework | PyTorch, TensorFlow, JAX | Model definition, training and inference
Machine learning tools | Scikit-learn | Traditional machine learning algorithms
Large model tools | LangChain, LlamaIndex, LangGraph | Agent development, RAG retrieval, planning and orchestration
Optimization tools | Optuna | Automatic hyperparameter optimization (built-in GA, PSO, etc.)
Model conversion | ONNX | Cross-frame model exchange format
Inference Engine | ONNX Runtime, TensorRT, RKNN | General purpose/NVIDIA GPU/Rockchip NPU inference acceleration

⚠️ Important Notes: PyTorch handles training, ONNX handles conversion, RKNN handles deployment, and LangGraph handles orchestration. Use different tools for each stage.

## II. Machine Learning Fundamentals

### 2.1 Three Paradigms of Machine Learning

#### 2.1.1 Supervised Learning

Core principle: Using labeled training data, the model learns the mapping relationship between input and output.

Core task:

- Classification: Predicting discrete labels (e.g., image classification, spam detection)
- Regression: Predicting continuous values ​​(such as housing price forecasts and sales forecasts)

Representative algorithms: Linear Regression, Logistic Regression, Decision Tree, Random Forest, SVM

Deep learning can be used in image classification and speech recognition (end-to-end, no manual feature extraction required).

#### 2.1.2 Unsupervised learning

Core principle: Use unlabeled training data to allow the model to automatically discover patterns and structures in the data.

Core task:

- Clustering: Grouping similar data (e.g., user segmentation, anomaly detection).
- Dimensionality reduction: Mapping high-dimensional data to a low-dimensional space (e.g., PCA, t-SNE).

Representative algorithms: K-means, DBSCAN, PCA

Deep learning can be used in the following ways: generative models (GANs generate images) and self-supervised pre-training (BERT predicts self-generated labels using masks).

#### 2.1.3 Reinforcement Learning

Core principle: Intelligent agents continuously optimize their behavioral strategies based on reward signals obtained by interacting with the environment in order to maximize long-term cumulative rewards.

Core concepts:

- Markov Decision Process (MDP): A mathematical framework for describing reinforcement learning problems
- Strategy: The agent's behavior function, which determines what action to take given a state.
- Reward: Feedback signals from the environment to the agent's actions

Representative algorithms include Q-learning (value function method), DQN (value function + deep learning), and PPO (policy gradient method). These three belong to the three major mainstream approaches in reinforcement learning—Q-learning (value function), DQN (value function + deep learning), and PPO (policy gradient + trust domain)—each suitable for different scenarios.

Deep learning can be applied in the following ways: game theory (AlphaGo, which incorporates supervised learning and reinforcement learning), robot motion planning, and RLHF (large model alignment technique).

⚠️ Important Note: Reinforcement learning and deep learning are orthogonal—reinforcement learning is a branch of machine learning independent of supervised/unsupervised paradigms, while deep learning is a tool for approximating the policy/value function in reinforcement learning. Deep Reinforcement Learning (DRL) is the fusion of the two.

### 2.2 Core General Concepts

concept | definition
:-- | :--
Overfitting/Underfitting | Overfitting: Performs well on training data but poorly on test data; Underfitting: Performs poorly on both training and test data.
Generalization ability | The ability of a model to predict new, unseen data is a core objective of machine learning.
Bias-variance tradeoff | Bias is the average error of the model's predictions, while variance is the degree of fluctuation in the model's predictions. Reducing bias usually increases variance, so a balance needs to be found.
loss function | The function that measures the difference between the model's predictions and the true labels is the optimization objective of model training.
Optimizer | Algorithms that update model weights based on the gradient of the loss function (such as SGD, Adam)
Evaluation indicators | Metrics for measuring model performance (such as accuracy, precision, recall, F1 score).

⚠️ Important Note: Traditional machine learning will not be completely replaced by deep learning; the two are complementary. Traditional machine learning is suitable for tasks involving small, structured data and can serve as an auxiliary tool for agents.

🔑 Key distinction: The three major paradigms are "problem dimensions," while deep learning is a "solution dimension." Deep learning is not a fourth major paradigm, but rather an advanced means of implementing the three major paradigms. Traditional machine learning can also implement the three major paradigms, but the advantage of deep learning lies in its "end-to-end" nature—it takes raw pixels/waveforms as input and directly outputs actions or labels, without the need for manual feature extraction.

## III. Core of Deep Learning

### 3.0 Summary and Overview

The deep learning system is divided into four levels:

hierarchy | name | Substantive content | Core Responsibilities
:-- | :-- | :-- | :--
1 | Underlying Mathematics and Optimization Theory | Neuron model (linear + activation), forward propagation, back propagation (chain rule), loss function (CrossEntropy/MSE), optimizer (SGD/Adam/AdamW), regularization (Dropout/Weight Decay), learning rate scheduling | Defines the complete mathematical rules and parameter update closed-loop logic for "how the model learns from the data." This is the absolute foundation, which all higher-level implementations must strictly adhere to and never change.
2 | Computing framework and execution engine | Training frameworks (PyTorch/TensorFlow/JAX/MXNet) include automatic differentiation; inference engines (ONNX Runtime/TensorRT/OpenVINO/RKNN Runtime) do not include automatic differentiation. | The training framework provides tensor operations, automatic differentiation, and GPU/NPU hardware acceleration; the inference engine performs operator fusion, quantization compression, and hardware instruction mapping to complete single forward inference.
3 | Model architecture design | CNN (ResNet/EfficientNet), RNN/LSTM/GRU, Transformer (GPT/BERT/ViT), Mamba (SSM), RWKV (Linear Attention), Hybrid (CLIP), MoE (Qwen-Max) | Defining the forward propagation path of data in the model, the feature extraction interaction mechanism, and the parameter organization method determines the receptive field, sequence modeling capability, and computational complexity.
4 | Hugging Face Ecosystem | transformers (AutoModel unified loading), tokenizers/sentencepiece, safetensors, peft (LoRA), trl (RLHF), datasets/evaluate, HF Hub | It provides a unified model interface and model repository specification across architectures and frameworks, with built-in dialogue templates and a multimodal processor, as well as an orchestration/fine-tuning/evaluation/deployment toolchain. It does not perform numerical calculations itself.

Dependency Chain: Underlying Mathematical Principles and Constraints → Architecture Design and Data Flow → Framework Execution and Numerical Computation → HF Ecosystem Scheduling and Orchestration

### 3.1 General Underlying Principles

Core principle: By stacking multiple layers of nonlinear transformations in a neural network, hierarchical feature representations are automatically learned from the data.

Basic unit of a neural network:

- Neuron: Receives input, performs a linear transformation (y = wx + b), and then introduces nonlinearity through an activation function.
- Fully connected layer: Each neuron is connected to all neurons in the previous layer, achieving a global linear combination of features.
- Activation function: Introduces nonlinearity, enabling neural networks to fit complex nonlinear functions (such as ReLU, SiLU, GELU).
- Normalization layers: accelerate training and stabilize gradients (e.g., Batch Normalization, Layer Normalization)

Core training process:

1. Forward propagation: Input data is processed layer by layer through the network to obtain the prediction result.
2. Loss calculation: The loss function is used to calculate the difference between the predicted result and the true label.
3. Backpropagation: According to the chain rule, the gradient of the loss with respect to each weight is calculated layer by layer from the output layer to the input layer.
4. Gradient descent: The optimizer updates the model weights based on the gradient, reducing the loss.

🔑 Key distinction: Discriminative models (classification/regression) learn the "boundary" (whether this image is a cat or a dog), and the training process is uniformly forward → loss → backward → gradient descent, with the only difference being in the feature extraction module. Generative models (GAN, diffusion models) learn the "distribution" (what a cat looks like, and then draw one), and their training processes differ.

### 3.2 Training the reasoning framework

Core positioning: The code execution base that implements underlying mathematical theories, providing underlying execution capabilities such as tensor operations, automatic differentiation, and GPU/NPU hardware acceleration for all network architectures.

⚠️ Important Notes: Any network architecture can only define the data flow topology logic and cannot independently complete numerical calculations; it must call the framework's built-in operators to perform forward propagation and backward gradient updates.

Four main frameworks:

- PyTorch: Dynamic Graph Execution. Most open-source models, including LLM/VLM/Mamba/RWKV, are trained using PyTorch. It's also the default backend for the Hugging Face ecosystem.
- TensorFlow: Static graph + Eager mode, still has a significant presence in traditional CV industrial projects and mobile deployments (TFLite).
- JAX: Functional + XLA compilation, experimental implementations used by Google DeepMind (Gemini) and Mamba.
- MXNet: An Apache archive that has fallen out of the mainstream ecosystem.

#### 3.2.1 Automatic Differentiation

What is automatic differentiation?

Autograd is a built-in "differentiation calculator" in deep learning frameworks. It can automatically track every mathematical operation in the model (addition, subtraction, multiplication, division, matrix multiplication, activation function) and accurately calculate the partial derivative (gradient) of the loss function with respect to each weight parameter.

What exactly does it do during training?

It is the code implementation of backpropagation:

1. Run the forward pass once: Calculate the prediction result from the input data, and calculate the total loss.
2. Automatic backtracking: Based on the loss, the framework automatically works backward along the computation path, using the chain rule to calculate the gradient of the parameters at each layer.
3. The gradient is passed to the optimizer (e.g., Adam), and the optimizer updates the weights.

The core differences between training frameworks and inference engines:

Comparison Dimensions | Full-featured training frameworks (PyTorch/TF/JAX) | Pure inference engine (ONNX Runtime/TensorRT)
:-- | :-- | :--
Does it include automatic differentiation? | Include | Not included
The inside story | It has a built-in, complete autograd engine that dynamically builds the computation graph and performs real-time differentiation at runtime. | There are only forward computation operators (Conv, MatMul, Add), but no backward differentiation logic.
What can be done? | It can perform both forward (reasoning) and backward (training) processes. | Forward computation is possible only. Input weights → Output results, then end.
Can it be trained? | Yes. It can calculate gradients and call the optimizer to update weights. | Absolutely not. There is no "differentiation" function module.

Conclusion: The reason why the inference engine does not support training is that the automatic differentiation module has been completely removed from its codebase, and only lightweight forward computation operators are retained in exchange for smaller size and more extreme inference speed.

### Overview of Computational Frameworks and Inference Engines

category | Frame Name | Training support | Reasoning support | Includes automatic differentiation | Main Scenes
:-- | :-- | :-- | :-- | :-- | :--
Training framework | PyTorch | support | support | Include | LLM/VLM/Mamba are absolutely mainstream, with a market share of 90%+.
Training framework | TensorFlow | support | support | Include | Industrial CV, mobile TFLite, primarily existing systems
Training framework | JAX | support | support | Include | Cutting-edge scientific research, TPU distributed computing (Gemini, Mamba experiments)
Training framework | MXNet | support | support | Includes (maintained but no longer in use) | Legacy systems, phased out of mainstream.
Inference Engine | ONNX Runtime | Not supported | support | Not included | Cross-platform NPU deployment (RK3588, Huawei Ascend)
Inference Engine | TensorRT | Not supported | support | Not included | NVIDIA GPU Extreme Optimization
Inference Engine | OpenVINO | Not supported | support | Not included | Intel CPU/VPU edge inference
Inference Engine | RKNN Runtime | Not supported | support | Not included | Rockchip NPU Dedicated Inference Stack

### 3.3 Four Mainstream Neural Network Architectures

#### 3.3.1 CNN (Convolutional Neural Network)

Core principles: Extract local features by sliding convolutional kernels across the input data; reduce the number of parameters by using weight sharing; and expand the receptive field by reducing dimensionality through pooling layers.

Core modules:

- Convolutional layers: extract local features (edges, textures, shapes)
- Pooling layers: reduce feature map size, decrease computation, and enhance feature robustness.
- Fully connected layer: maps the features extracted by convolution to the output space.

Applicable scenarios: Visual perception tasks (the agent's "eyes"), such as image classification, object detection, and image segmentation.

Representative models: ResNet, YOLO, VGG, MobileNet

#### 3.3.2 RNN/LSTM Recurrent Neural Networks

Core principle: LSTM processes sequential data by passing historical information through recurrent hidden states. LSTM solves the vanishing gradient problem of traditional RNNs through gating mechanisms (input gate, forget gate, output gate).

Applicable Scenarios: In the Large Language Model (LLM) field, Transformer is the mainstream foundation, while RNN/LSTM has taken a backseat. However, RNN/LSTM remains the primary choice in the following scenarios:

- Time Series Prediction/Anomaly Detection: Multivariate Time Series Modeling, LSTM/GRU and Transformer Each Have Their Advantages and Disadvantages
- Sensor signal processing: Industrial signals with high real-time requirements and extremely long sequences
- Low-performance edge devices: On STM32/low-end MCUs, LSTM inference overhead is far lower than that of Transformer.

Representative models: LSTM, GRU

🔑 Key distinction: RNN/LSTM and Transformer are complementary, not replacements. It's inaccurate to say that RNN/LSTM is "replaced".

#### 3.3.3 Transformer

Core principle: Through a multi-head self-attention mechanism, the association between each position in the sequence and all other positions is directly calculated to achieve global context modeling; positional information of the sequence is introduced through positional encoding.

Core modules:

- Multi-head self-attention: Maps input features to multiple heads, calculates attention for each head separately, and then concatenates the results to capture semantic relationships across different dimensions.
- Feedforward Network (FFN): Performs nonlinear transformation on the features at each location.
- Residual connections and LayerNorm: accelerating training and preventing gradient vanishing

Applicable scenarios: Language, logic, and multimodal tasks (the core of the agent's brain)

Representative models: GPT, LLaMA, BERT, ViT

🧠 Core understanding: Pure Transformer large models do not contain convolutions. Convolutions are not necessary for all models; pure large language models can completely eliminate the need for convolutions.

#### 3.3.4 Mamba and RWKV

**Mamba**

Core principle: Long sequence modeling is achieved through the linear recursive mechanism of the Selective State-Space Model (S6). Mamba is based on the state-space model of continuous-time control systems, with its discrete form being xt+1=Axt+But and yt=Cxt+Dut, which is a state recursive framework derived from control theory. Its time complexity is O(n), far lower than the Transformer's O(n²).

Applicable scenarios: Accelerating inference for agents with very long contexts and large models.

Representative model: Mamba (a general state space block that can be used to build LLM/VLM/speech modal models)

**RWKV**

Core Principle: RWKV (Receptance Weighted Key Value) is a novel architecture that combines the efficient parallel training of Transformers with the efficient inference of RNNs. Its core is a linear attention mechanism + token shift, officially positioned as a variant of RNN. Mathematically, RWKV can be equivalently expressed as a state-space model, but its design originates from a linear attention approximation, rather than a cybernetics state-space model.

Applicable scenarios: Accelerating inference for agents with very long contexts and large models.

Representative model: RWKV (Plain text large model architecture, compatible with Hugging Face format)

- Mamba = Native Selective-SSM (Cybernetic State-Space Model)
- RWKV is a variant of RNN and linear attention. Mathematically, it can be equivalently expressed in the form of SSM, but its design origin is not from cybernetics SSM.

🔑 Key distinction: Although both aim to replace Transformer's O(n²) with linear complexity, their implementation principles and design origins are fundamentally different.

### Architecture Selection Quick Reference

Architecture | Applicable Scenarios | One-sentence advice
:-- | :-- | :--
CNN | Agent visual perception | Use it to view the picture
RNN/LSTM | Timing prediction, edge low power consumption | While it has taken a backseat in the LLM field, it remains the mainstay in timing/device-side applications.
Transformer | Agent (Brain - Language/Reasoning) | Current absolute main force
Mamba | Accelerated Inference for Very Long Sequences (SSM Route) | One of the future directions of long context
RWKV | Accelerated Inference for Very Long Sequences (Linear Attention Approach) | One of the future directions of long context

### 3.4 Hugging Face Ecosystem

Core positioning: A standardized toolchain and model repository independent of the engine and architecture, without underlying computing capabilities.

Core components:

- Transformers: A unified loading interface (AutoModel) that supports automatic routing across the entire architecture.
- tokenizers / sentencepiece: tokenization and encoding
- safetensors: A secure weighted serialization format (completely replacing .ckpt and .bin).
- Peft: Efficient fine-tuning of parameters such as LoRA and QA-LoRA
- trl: RLHF training based on reinforcement learning (PPO, DPO)
- datasets / evaluate: Dataset loading and standard evaluation metrics
- HF Hub: A model repository and dataset hosting platform

Core function:

- A single loading interface is compatible with all architectures including CNN/RNN/Transformer/Mamba.
- Automatically adapts to the three major computing engines: PyTorch, TensorFlow, and JAX.
- Standardize the HF model folder (config.json, tokenizer, segmentation weights)
- Built-in dialogue templates, image preprocessing, and batch inference logic
- A complete toolchain for orchestration, fine-tuning, evaluation, and deployment.

Dependency chain: HF tool → Instantiate the corresponding architecture network → Call the computing engine to complete forward propagation inference/training

### 3.5 Deep Learning Optimization Techniques

#### 3.5.1 Gradient-based optimization

Core principle: Based on the gradient of the loss function, fine-tune the model weights in the opposite direction of the gradient to gradually reduce the loss.

Representative algorithms:

- SGD (Stochastic Gradient Descent): Updates weights using only one sample at a time; fast but prone to large fluctuations.
- Adam: Combining momentum and adaptive learning rate, it converges quickly and has good stability, making it the most commonly used optimizer currently.
- Learning rate scheduling: The learning rate is dynamically adjusted during training. A large learning rate is used in the early stage for rapid convergence, and a small learning rate is used in the later stage for fine-tuning (strategies such as Step, Cosine, Warmup, etc.).

⚠️ Important Note: In the main training of deep neural networks, gradient-based optimization (such as SGD and Adam) is the absolute mainstream paradigm and dominates the industry. However, please note:

1. Training decision trees and random forests does not rely on gradient descent; while gradient boosting trees (GBDT) such as XGBoost essentially use gradient descent for optimization.
2. Evolutionary strategy (ES) can be used as an alternative training method for policy networks in reinforcement learning, directly optimizing parameters and belonging to the main training scope of policy networks.

#### 3.5.2 Non-gradient optimization

Core principle: It does not rely on gradients, but seeks the best through random search and iterative selection, making it suitable for discrete combinatorial optimization problems.

Representative algorithms:

- Genetic Algorithm (GA): Mimics biological evolution, iteratively selecting the optimal solution through selection, crossover, and mutation.
- Particle Swarm Optimization (PSO) algorithm: mimics the foraging behavior of birds, finding the optimal position by having particles move towards their own optimal position and the global optimal position.
- ACO (Ant Colony Algorithm): Mimicking the pheromone update mechanism of ant foraging paths

Applicable scenarios: Network Architecture Search (NAS), hyperparameter optimization, initial weight optimization

⚠️ Important Note: Bionic algorithms are mostly used for optimizing pre-structure/hyperparameters/initial weights in most deep learning scenarios. However, evolutionary strategies (ES) can be used as an alternative training method for policy networks in reinforcement learning, falling under the category of "main training".

#### 3.5.3 Regularization

Core principle: By limiting the complexity of the model, overfitting is prevented and generalization ability is improved.

Representative technologies:

- Dropout: Randomly discards some neurons during training.
- L1/L2 regularization: Adding a penalty term to the weights in the loss function.
- Early stopping: Stop training when the validation set loss no longer decreases.

## IV. Foundation of the Large Model

### 4.1 Core Technology Stack of the Large Model

#### 4.1.1 Pre-training

Core principle: Using massive amounts of unlabeled text data, the model learns common language rules and common sense knowledge through self-supervised learning tasks (such as predicting the next token), and compresses this knowledge into the weight parameters.

Key features: The pre-trained large model has general language understanding and generation capabilities, and can be fine-tuned to adapt to various downstream tasks.

#### 4.1.2 Fine-tuning

Core principle: Based on the pre-trained model, continue training using a small amount of labeled data to teach the model to follow instructions and complete specific tasks.

Mainstream technologies:

- Full fine-tuning: updates all weights of the model, yields good results, but has high computational cost.
- SFT (Supervised Fine-Tuning): Fine-tuning using human-annotated instruction data, allowing the model to learn to follow instructions.
- LoRA/QLoRA: Low-rank adaptation techniques that update only a small number of model parameters, resulting in low computational cost and performance close to full fine-tuning.

🔑 Key distinction: Fine-tuning can inject new knowledge (vertical domain medical/legal models absorb professional knowledge through fine-tuning), but it is inefficient, carries the risk of catastrophic forgetting, and is difficult to verify the specific content injected. For high-precision, real-time, and frequently changing factual knowledge, RAG is superior; for professional jargon that needs to be solidified into the model's behavior, fine-tuning is more suitable.

#### 4.1.3 Alignment

Core principle: Ensure that the output of large models aligns with human values ​​and preferences, avoiding the generation of harmful, false, or biased content.

Mainstream technologies:

- RLHF (Reinforcement Learning Based on Human Feedback): First, human annotators rank the model outputs, then a reward model is trained, and finally, a reinforcement learning algorithm (such as PPO) is used to optimize the large model.
- DPO (Direct Preference Optimization): This method directly optimizes the model using human preference data, without requiring an explicit reward model. However, its stability differs from RLHF, and the issue remains under discussion in academia.

### 4.2 Large Model Inference and Augmentation Techniques

#### 4.2.1 Original Reasoning

Core principle: Autoregressive token generation – Each time a token is generated, it is added to the context, and then the next token is generated, until the end token is generated.

Key features:

- Using only the parameterized knowledge of weighted compression
- No network connection or external tool invocation is triggered (referring to pure parametric inference mode).
- Inference cost is proportional to the number of input and output tokens.

🧠 Core understanding: In pure parametric inference mode, the native large model does not connect to the internet or look up databases, but only uses knowledge compressed within the weights.

#### 4.2.2 Industrial-grade Enhanced Inference: RAG Retrieval Enhancement

Core principle: Retrieve knowledge from external knowledge bases, combine it with user questions to form a Prompt, and let the large model generate answers based on the retrieved real knowledge.

Standard three-step model:

1. Retrieval: Vectorizes user questions and retrieves relevant document fragments from external knowledge bases.
2. Augmentation: Adds supporting data retrieved to the suggestion words.
3. Generation: LLM generates answers based on enhanced prompts.

Complete process details:

1. User Questions
2. Problem Analysis and Rewriting (Optional)
3. Searching local knowledge bases / Web search engines
4. Search result relevance ranking and deduplication
5. Extracting high-credibility reference text
6. Building a Prompt: System Commands + User Questions + Searching for References
7. Feed the data into a large model to generate the answer.

🧠 Core understanding: RAG is responsible for providing facts, while the large model is responsible for generation and reasoning, and the boundaries between the two are clear.

⚠️ Note: Large models will not automatically search the network in pure parametric inference mode; all retrieval actions are performed by the external RAG module.

## V. Agent (Intelligent Agent)

### 5.1 Agent Core Definition and Five Components

🧠 Core Concept: Agent = Brain (Large Model) + Memory + Planning + Tools + Skills

The large model is merely the brain of the agent, not the complete agent. The five components have clearly defined roles, and none can be omitted.

#### 5.1.1 Brain (Large Model)

Core responsibilities: decision-making, language generation, and logical reasoning.

Detailed Explanation of Principles: As the core of the Agent, it receives the context processed by the planning module and generates decision-making, reasoning processes, and natural language responses.

Project mapping: RKLLM (local NPU inference), llama.cpp (CPU inference), cloud API (DeepSeek/GPT/Claude)

#### 5.1.2 Memory Module

Core responsibilities: Managing short-term context, long-term vector memory, skill usage records, and dynamic loading and unloading.

Four-layer memory architecture:

1. Short-term context memory: The content within the current dialog window is directly fed into the large model.
2. Working memory: the intermediate execution state of the current task.
3. Long-term vector memory: Historical dialogues and knowledge base content are stored in a vector database.
4. Skill memory: List of installed skills and usage history

Dynamic loading and unloading: Based on the needs of the current task, only relevant memory content is loaded into the context, and irrelevant content is unloaded to avoid context explosion.

Project mapping: LlamaIndex (memory building) + Chromadb (vector storage)

⚠️ Important Note: More memory is not necessarily better. The key is to "remember what should be remembered and forget what should be forgotten"—the context window is limited, and stuffing irrelevant history in will only distract the larger model.

#### 5.1.3 Planning Module

Core responsibilities: Task breakdown, step orchestration, execution status management, failure rollback, reflection and correction, and multi-skill combination orchestration.

Detailed Explanation of the Principle: The user's complex task is broken down into executable subtasks, execution steps are arranged, the execution status of each step is managed, rollback and retry are performed when a step fails, and reflection and summary are performed after the task is completed.

Multi-skill combination and arrangement: According to the needs of the task, multiple skills can be combined in a serial, parallel or conditional branching manner to complete complex professional tasks.

Project mapping: LangGraph (precise state machine control, recommended), CrewAI (role-playing orchestration), custom while loop (lightest weight).

#### 5.1.4 Tool Invocation

Core responsibility: Execute a single external action (API/CLI/database/GPIO)

Detailed Explanation of the Principle: As the interface between the Agent and the external world, it receives instructions from the planning module, executes a single external action, and returns the result to the planning module. One tool does only one thing.

⚠️ Note: The tool does not make high-level task decisions (such as "what to call next"), but allows execution-level local decisions (such as timeout retries, error code mapping, and filtering of return result sets).

Project mapping: MCP protocol (standard tool integration method), custom hardware driver functions (GPIO/camera/PWM encapsulation)

🔑 Key distinction: Tool = Single API call; Skill = Complete workflow + Best practices + Error handling.

#### 5.1.5 Skills

Core Responsibilities: Providing professional workflows, best practices, and error handling templates.

Detailed Explanation of the Principle: Encapsulate domain-specific expertise and workflows into standardized skill packages, enabling agents to perform specialized tasks without needing to relearn.

Project mapping: SKILL.md file

⚠️ Important Notes: Skills do not schedule tasks across tasks or make global decisions beyond their authority.

Example of five components working together: The user says, "Please check if this sensor is working properly." The brain determines the intention → plans the disassembly steps (initialization → reading → verification → reporting) → calls the tool to perform GPIO reading → rolls back and retry if it fails → stores the result in memory → the brain generates the final report.

### 5.2 Single Agent Mainstream Architecture Pattern

model | Core idea | Key features
:-- | :-- | :--
ReAct | Intertwining reasoning and action | The Thought-Action-Observation (TAO) closed loop: At each step, the "Thought" and "Action" are explicitly output, and then the subsequent reasoning is updated using environmental feedback (Observation). This loop continues until the task is completed. It is the most basic and commonly used Agent loop.
Reflexion | ReAct + Language Feedback and Reflection | Core innovation: Instead of updating model weights, the agent is reinforced through language feedback. When a task fails, the agent writes the failure experience into an Episodic Memory Buffer in natural language form. In the next attempt, this is injected as a contextual signal to guide the model around the error. No gradient-based weight updates are required.
Plan-Execute-Reflect | Planning → Execution → Reflection (Three Stages) | The standard paradigm consists of three phases: ① Planning: The LLM (Limited Planner) uses available tools to generate an initial step-by-step plan; ② Execution: The plan is executed step by step in sequence; ③ Re-evaluation/Reflection: After each step, the replanner dynamically re-evaluates the plan based on the intermediate execution results, skipping, adding, or modifying subsequent steps. Systems lacking the reflection phase lack fault tolerance.
Industrial-grade hybrid | The above models are integrated | Products like Claude Code use the ReAct class internally for looping code exploration and modification, and natively integrate the Skills standard.

### 5.3 Agent Capability Extension: Skills Open Standard

Origin: Anthropic first launched the Skills feature in Claude Code in October 2025, and in December of the same year, together with ecosystem partners, it was officially upgraded to the Agent Skills Open Standard and launched on the [agentskills.io](https://agentskills.io/) website.

Core principle: Progressive disclosure—When the agent starts, it only loads the SKILL.md manifest (containing the name, description, input, and output of the skill). The complete instructions and code are loaded only when a skill needs to be invoked. This solves the context explosion problem caused by traditional agents loading all instructions at once.

Skill file standard structure:

- Folders: One separate folder for each Skill
- SKILL.md: Contains a YAML header (metadata: name, description) and Markdown directives (workflow, best practices, error handling).
- scripts/: Optional, contains script files required for Skill execution.

The fundamental difference between a tool and a skill is that a tool is a single API, while a skill is a complete workflow plus best practices plus error handling.

Skill Development Process: Write SKILL.md → Install and test locally → Publish and share to the community

### 5.4 Multi-Agent System

Mainstream architecture:

- Master-slave architecture: One master agent is responsible for task allocation and coordination, while multiple specialized agents are responsible for executing specific tasks.
- Federal model: Multiple equal agents work together to complete a task.
- Hierarchical structure: Multiple agent layers with different roles, where higher layers are responsible for strategic planning and lower layers are responsible for tactical execution.

Core technologies: role division, communication protocols, task allocation, and conflict resolution.

Project mapping: AutoGen (multi-agent collaboration framework), CrewAI (role-driven orchestration), LangGraph (subgraph/hierarchical graph topology)

### 5.5 Agent Design

text

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ 1. 整体公式: Agent = Model + Harness（Harness Engineering概念由Mitchell         │
│    Hashimoto提出，该等式由LangChain/OpenAI归纳推广）                             │
├────────────────────────────────────────────────────────────────────────────────┤
│ 2. 系统构建: Agent 运行在 Harness 之上，由 Harness 提供工程底座                   │
├────────────────────────────────────────────────────────────────────────────────┤
│ 3. 调度与组织: Orchestrator + Workflow Patterns 负责管理多个 Agent 或 LLM 调用   │
├────────────────────────────────────────────────────────────────────────────────┤
│ 4. 决策驱动: Agent 内部由 ReAct/Reflexion/Plan-Execute-Reflect 等认知模式驱动     │
├────────────────────────────────────────────────────────────────────────────────┤
│ 5. 能力扩展:                                                                    │
│    - Agent 通过 MCP 协议调用外部工具                                             │
│    - Agent 按需加载 Skills 技能包                                               │
└────────────────────────────────────────────────────────────────────────────────┘
```

**Harness's core components (six main parts)** :

The following six component categories are common summaries of Harness's practical experience in the community, and are not Mitchell Hashimoto's original definition or LangChain's official standard.

Components | Description and Functions
:-- | :--
1. File System | Provides the ability to read, write, and edit files, enabling the Agent to interact with the local file system.
2. Bash + Sandbox | Provides a secure command execution environment, allowing agents to run shell commands in a controlled environment.
3. Memories (AGENTS.md / CLAUDE.md) | Standard files provide long-term memory and rules, allowing agents to adhere to project conventions. The two functions correspond but have different filenames.
4. Web Search + MCP | Integrating web search capabilities and the MCP protocol enables the agent to obtain external information and invoke standardized tools.
5. Context Engineering | Manage and optimize the context passed to the model to ensure it is efficient, relevant, and within limits.
6. Arrangement + Hooks | Provides task orchestration and lifecycle hooks to manage execution processes and supports state persistence and recovery.

**Component Quick Reference:**

Components | One-sentence definition | source
:-- | :-- | :--
LLM | The "intelligent core" provides basic understanding and generative capabilities. | Large Model Domain Consensus
Harness | The engineering infrastructure that fills the gaps in LLM, the "engineering foundation" of the agent. | Harness's core architecture formula: Agent = Model + Harness
Agent | A goal-oriented intelligent execution unit running on Harness. | Consensus in the Agent/Intelligent Agent Domain
MCP | Standardized open protocols for connecting AI applications with external data and tools | Model Context Protocol (Official Protocol)
Skills | Encapsulate standardized "capability modules" that encapsulate specific domain knowledge or processes. | Agent Skills Open Standard
Cognitive patterns | The core algorithm that guides how the agent thinks and makes decisions internally. | Original paper on ReAct/Reflexion/Plan-Execute-Reflect
Workflow pattern | The top-level structure for organizing and orchestrating agent or task execution processes. | Anthropic Engineering Blog
Multi-Agent | System architecture for multiple agents to collaborate in completing complex tasks | Consensus in the field of multi-agent systems

## VI. Engineering Implementation

### 6.1 Model Engineering (Optimizing Computational Costs)

Core objective: To make models run faster and with less computational power, reducing inference latency and hardware costs.

Core technologies:

- Quantization: Converts the model's weights and activations from 32-bit floating-point numbers to 16-bit, 8-bit, or even 4-bit integers, reducing computation and memory usage with minimal loss of accuracy.
- Pruning: Remove unimportant weights and neurons from the model to reduce the number of model parameters.
- Knowledge distillation: Using a large model (teacher model) to train a small model (student model), enabling the small model to possess capabilities approaching those of the large model.

Standard deployment pipeline: PyTorch model → ONNX conversion → RKNN quantization → edge device NPU inference

⚠️ Note: Model engineering operations (quantization, pruning) will change the precision and distribution of model weights, thus affecting the distribution of output values.

### 6.2 Agent Engineering (Optimizing Data Volume/Token Cost and Task Flow Reliability)

Core objectives: Reduce input/output token consumption, improve agent operating efficiency and task execution reliability, and reduce inference costs.

The essential difference between model engineering and model engineering:

- Model engineering: Optimizing computational load (modifying the model itself)
- Agent Engineering: Optimizing data flow and task reliability (without changing the model, but modifying the input/output organization).

Optimization directions (the community has exploratory tools, but a unified industry standard has not yet been formed):

- Context trimming: Automatically trims long dialogue history, retaining only content relevant to the current task.
- On-demand memory loading: Long-term memory is stored in a vector database and retrieved and loaded on demand.
- CLI output filtering: Compresses the output of command-line commands, removing irrelevant formatting and redundant information.
- Cross-session memory system: Efficiently manage long-term memory across sessions

### 6.3 MLOps and AIOps

Core objective: To achieve automated management of the entire lifecycle of AI models and agents, thereby improving development efficiency and system stability.

Core content:

- Data management: data collection, cleaning, labeling, and version management
- Model version management: model training, version control, model repository
- Monitoring and Operations: Model performance monitoring, error monitoring, resource monitoring
- A/B testing: Comparative testing of different models and agent versions.
- Agent lifecycle management: Agent development, testing, deployment, upgrade, and decommissioning.
- Observability: Agent execution trajectory tracking, token consumption monitoring, task completion rate statistics (tools: LangSmith, LangFuse, AgentOps)

### 6.4 Model Evaluation

Evaluation type | index
:-- | :--
Traditional NLP evaluation | GLUE, BLEU, ROUGE
Agent Evaluation | Task completion rate, trajectory similarity, and user evaluation agreement
RAG Review | Search accuracy, answer fidelity.

## VII. Safety Ethics and Regulations

### 7.1 Technical Security

#### 7.1.1 Model Safety

- Dedistillation: Prevents attackers from distilling the model's weights and knowledge by querying the model's output, thus protecting the model's intellectual property.
- Adversarial attack defense: Preventing attackers from constructing malicious inputs to cause the model to produce incorrect outputs.
- Model theft protection: Prevents attackers from directly stealing deployed model files.

#### 7.1.2 Skill Safety

- Skill security sandbox: isolates running Skill code to prevent malicious Skills from accessing system resources, stealing data, or damaging the system.
- Access control: Assign minimum necessary permissions to each Skill.
- Input/output filtering: Filters Skill input and output to prevent injection attacks and sensitive information leakage.
- Malicious code detection: Scans skills in the public skill library to detect malicious code.

#### 7.1.3 Data Security

- Data privacy protection: Training data and user data are anonymized to prevent privacy leaks.
- Data encryption: Encrypting data during storage and transmission.
- Access control: Strictly control access permissions to data.

#### 7.1.4 Jailbreak Prevention

- Prompt injection and jailbreak attacks were more common in the agent era.
- Agent-specific injection protection, system command protection, and input/output content security guards.

### 7.2 Hot Ethical Issues

- Colleague.skill: Employees packaging their professional skills and work experience as "skills" has sparked controversies regarding workplace privacy, intellectual property ownership, and employee replacement.
- Knowledge Value Attribution: The copyright ownership of content generated by RAG retrieval—whether it belongs to the original author, the knowledge base provider, or the large model vendor—currently lacks a clear legal consensus globally.
- The right to be forgotten in digital avatars: The EU AI Act explicitly requires that users have the right to request the deletion of their digital avatars and related data.
- Algorithmic bias and fairness: Agents may inherit biases from the training data during the decision-making process, leading to discriminatory results.

### 7.3 Global AI Regulations

Regulations | Core content
:-- | :--
EU AI Act | The world's first comprehensive AI regulation categorizes AI systems into four risk levels, imposing strict oversight on high-risk AI systems.
Interim Measures for the Administration of Generative AI Services in China | The regulations clearly define the requirements for registration, data security, and content compliance of generative AI services.
US AI Executive Order | Federal government agencies are required to ensure that the use of AI is safe, trustworthy, and accountable.

## Quick Reference for Common Misconceptions

❌ Common Misconceptions | ✅ Precise expression
:-- | :--
PyTorch is a model | PyTorch is a deep learning computing framework used to define, train, and run models (such as Transformer and CNN), but it does not contain any model parameters or knowledge itself.
The large model stores all knowledge | Large models compress training data into parameterized common sense and patterns; this knowledge is fuzzy, imprecise, and has deadlines. High-precision, time-sensitive knowledge needs to be dynamically retrieved and injected from authoritative external sources via RAG.
The model was trained using a genetic algorithm. | Evolutionary strategies, such as genetic algorithms, are typically used in the early stages of hyperparameter search or neural architecture search (NAS); the main training of the model relies entirely on gradient-based optimization (such as AdamW + backpropagation). Evolutionary strategies, as alternative training methods for policy networks in reinforcement learning, are an exception.
Skill refers to the use of tools. | A Skill is a complete capability unit that encapsulates tool calls, input validation, error retries, result parsing, and business logic, rather than a raw API call.
Agent engineering is model quantization | Model engineering focuses on computational efficiency (quantization/compilation/deployment), while agent engineering focuses on task flow reliability (memory management, planning rollback, tool collaboration, state persistence). Their goals differ, and they often need to collaborate.
The context of a large model is memory. | Large model contexts are temporary, volatile, and length-limited input buffers; long-term, structured, and updatable memories must be implemented by external vector libraries or databases.
Large models are naturally good at planning | Large models can generate seemingly reasonable plans, but they lack goal consistency, state awareness, and rollback mechanisms; industrial-grade agents must introduce independent planning logic (such as state machines and tree search) to ensure reliability.
Fine-tuning allows the model to remember new knowledge. | Fine-tuning can inject knowledge, but it is inefficient, carries the risk of catastrophic forgetting, and is difficult to verify. For factual knowledge that is highly accurate, real-time, and frequently changing, RAG is better. For professional language that needs to be solidified into the model's behavior, fine-tuning is more suitable.

## Conclusion

The development of the entire AI field is a process of continuously transforming "general-purpose large models" into "industrial-grade agents that can reliably solve practical problems".

- The brain is responsible for thinking, memory is responsible for remembering, planning is responsible for taking things step by step (including reflection and correction), tools are responsible for doing things, and skills are responsible for professional skills.
- RAG provides real-time facts, model engineering makes it run fast, and agent engineering makes it run intelligently.
- Safety ethics is the fuse that allows it to serve society on a large scale.
