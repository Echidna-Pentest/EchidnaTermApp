//
//  LocalLLM.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/10/31.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation
import llama
import SwiftUI

import Foundation

public class LocalLLM: LLM {

    // Static shared instance for Singleton pattern
    public static var shared: LocalLLM?

    // Convenience initializer
    public convenience init?(_ update: @escaping (Double) -> Void) async {
            let fileContent = Self.loadFileContent()
            let systemPrompt = "You are a pen test assistant. Use DB as a ref.\nDB: \(fileContent) "
//        let systemPrompt = "Penetration test assistant. Provide precise and actionable recommendations with minimal text."
    //        let model = HuggingFaceModel("TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF", .Q2_K, template: .chatML(systemPrompt))
    //        let model = HuggingFaceModel("TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF", template: .chatML(systemPrompt))
    //        let model = HuggingFaceModel("mav23/Pentest_AI-GGUF", .Q2_K, template: .chatML(systemPrompt))
    //        let model = HuggingFaceModel("TheBloke/OpenHermes-2.5-Mistral-7B-GGUF", template: .chatML(systemPrompt))
    //          let model = HuggingFaceModel("bartowski/Meta-Llama-3.1-70B-Instruct-GGUF", template: .chatML(systemPrompt))
    //          let model = HuggingFaceModel("microsoft/Phi-3-mini-4k-instruct-gguf", template: .chatML(systemPrompt))
    //        let model = HuggingFaceModel("microsoft/Phi-3-mini-4k-instruct-gguf", .Q4_1, template: .chatML(systemPrompt))


    //        let model = HuggingFaceModel("microsoft/Phi-3-mini-4k-instruct-gguf", .Q4_K_M, template: .chatML(systemPrompt))
    //        let model = HuggingFaceModel("TheBloke/CodeLlama-7B-GGUF", template: .chatML(systemPrompt))
    //        let model = HuggingFaceModel("QuantFactory/Meta-Llama-3-8B-Instruct-GGUF", .Q2_K, template: .chatML(systemPrompt))
//        let model = HuggingFaceModel("QuantFactory/Meta-Llama-3.1-8B-GGUF", .Q4_0, template: .chatML(systemPrompt))
//            let model = HuggingFaceModel("QuantFactory/Meta-Llama-3.1-8B-GGUF", .Q4_0, template: .chatML(systemPrompt))
//        let model = HuggingFaceModel("NousResearch/Hermes-3-Llama-3.1-8B-GGUF", .Q4_K_M, template: .chatML(systemPrompt))
//        let model = HuggingFaceModel("bartowski/Meta-Llama-3.1-8B-Instruct-GGUF", .Q4_K_M, template: .chatML(systemPrompt))
        let model = HuggingFaceModel("hugging-quants/Llama-3.2-3B-Instruct-Q8_0-GGUF", .Q8_0, template: .chatML(systemPrompt))
        do {
            try await self.init(from: model) { progress in update(progress) }
        } catch {
            print("Model initialization failed: \(error)")
            return nil
        }
    }
    
    /*
    public func analyzeFixedInput() async {
        let input = "What is the most popular food in Japan?"
        print("AnalyzeFixedInput input=", input)
        await respond(to: input)
        print("Analysis result: \(output)")
    }
     */
    
//    public func analyzeInput(commandOutput: String) async {
    public func performLocalAIAnalysis(input: String, fromUserRequest: Bool = false) async {
        guard fromUserRequest || UserDefaults.standard.bool(forKey: "EnableLocalLLMAnalysis") else {
            print("AI Analysis is disabled.")
            return
        }
        let fileContent = Self.loadFileContent()
        let systemPrompt = "You are a pen test assistant. Use DB as a ref.\nDB: \(fileContent)"
        let model = HuggingFaceModel("hugging-quants/Llama-3.2-3B-Instruct-Q8_0-GGUF", .Q8_0, template: .chatML(systemPrompt))
        
        if (fromUserRequest == true){
            let instruct = "Answer the question concisely from the user. \nQuestion: \(input)"
//            print("instruct=", instruct)
            await respond(to: instruct)
//            print("Analysis result: \(output)")
            ChatViewModel.shared.sendMessage("LocalLLM Response\n" + output, source: 0)
            return
        }
//        print("Analyzing input:", input)
//        let cleanedString = input.replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)

        /*
        let instruct = "You are a penetration test assistant. Analyze the provided console output and suggest up to 3 relevant commands that might be used to exploit the vulnerabilities or weaknesses discovered. If no vulnerabilities are found or no action is required, simply respond with 'NONE'. Return the result as a JSON object with two keys: 'commands' and 'vulnerability'. The 'commands' key should contain an array of commands, where each entry contains the command as a string and a brief explanation as another string, like this:\n{\n  \"commands\": [\n    {\n      \"command\": \"example command\",\n      \"explanation\": \"brief explanation\"\n    },\n    ...\n  ],\n  \"vulnerability\": \"Brief description of the most concerning vulnerability\"\n}\nIf no commands are applicable, return an empty array for 'commands'. \(cleanedString)"
*/
        let instruct = """
        Review Console Output below. Suggest one command if critical vulnerabilities are detected; otherwise, return 'NONE'. Respond with only the command in plain text.

        
        Console Output:
        \(input)
        """
        print("instruct=", instruct)
        
/*
        let instruct = """
        Analyze the ConsoleOutput and identify any vulnerabilities. 
        If there are vulnerabilities, respond concisely and return the most relevant vulnerability details as plain text.
        If no similar vulnerabilities are found, respond with 'NONE' to avoid providing misleading information.
                
        # ConsoleOutput (Analysis Target)
        \(input)
        """
  */
        await respond(to: instruct)
//        print("Analysis result: \(output)")
  
        if output.lowercased() != "none" && !output.isEmpty {
//            print("TargetTreeViewModel.shared=", TargetTreeViewModel.shared.targets)
//            let result = replaceIPAddressWithHost(in: output)
            // Extract the first line of output and take the first 70 characters
            let firstLine = output.components(separatedBy: "\n").first ?? ""
            let truncatedOutput = String(firstLine.prefix(70))
            let newCommand = Command(
                template: truncatedOutput,
                patterns: [],
                condition: [],
                group: "LocalLLM",
                description: ""
            )
            CommandManager.shared.addCommand(newCommand)
 //           ChatViewModel.shared.sendMessage("LocalLLM Analysis Summary\n" + output.prefix(300), source: 0)
        }
        
//        APIManager.processAnalysis(analysis: output, llmName: "LocalLLM", source: 0)
    }
    
    // Function to get or create a shared instance
    public static func getInstance(update: @escaping (Double) -> Void) async -> LocalLLM? {
        if let bot = shared {
            // Return existing instance if it exists
            return bot
        } else {
            // Otherwise, create a new instance and store it in shared
            shared = await LocalLLM(update)
            return shared
        }
    }
    
    public static func loadFileContent() -> String {
//        if let fileURL = Bundle.main.url(forResource: "Blue", withExtension: "json") {
        if let fileURL = Bundle.main.url(forResource: "merged_data", withExtension: "json") {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                print("content=", content)
                return content
            } catch {
                print("Error reading file content: \(error)")
                return "Error reading content."
            }
        } else {
            print("File not found in bundle.")
            return "File not found."
        }
    }
    
    public func replaceIPAddressWithHost(in output: String) -> String {
        // Regular expression pattern for matching IPv4 addresses
        let pattern = #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"#
        
        // Create a regular expression object
        let regex = try? NSRegularExpression(pattern: pattern)
        
        // Replace any IP addresses in the string with "{host}"
        let modifiedOutput = regex?.stringByReplacingMatches(in: output, options: [], range: NSRange(output.startIndex..., in: output), withTemplate: "{host}") ?? output
        
        return modifiedOutput
    }
}

public typealias Token = llama_token
public typealias Model = OpaquePointer
public typealias Chat = (role: Role, content: String)

@globalActor public actor InferenceActor {
    static public let shared = InferenceActor()
}

open class LLM: ObservableObject {
    public var model: Model
    public var history: [Chat]
    public var preprocess: (_ input: String, _ history: [Chat]) -> String = { input, _ in return input }
    public var postprocess: (_ output: String) -> Void                    = { print($0) }
    public var update: (_ outputDelta: String?) -> Void                   = { _ in }
    public var template: Template? = nil {
        didSet {
            guard let template else {
                preprocess = { input, _ in return input }
                stopSequence = nil
                stopSequenceLength = 0
                return
            }
            preprocess = template.preprocess
            if let stopSequence = template.stopSequence?.utf8CString {
                self.stopSequence = stopSequence
                stopSequenceLength = stopSequence.count - 1
            } else {
                stopSequence = nil
                stopSequenceLength = 0
            }
        }
    }
    
    public var seed: UInt32
    public var topK: Int32
    public var topP: Float
    public var temp: Float
    public var historyLimit: Int
    public var path: [CChar]
    
    @Published public private(set) var output = ""
    @MainActor public func setOutput(to newOutput: consuming String) {
        output = newOutput
    }
    
    private var context: Context!
    private var batch: llama_batch!
    private let maxTokenCount: Int
    private let totalTokenCount: Int
    private let newlineToken: Token
    private var stopSequence: ContiguousArray<CChar>?
    private var stopSequenceLength: Int
    private var params: llama_context_params
    private var isFull = false
    private var updateProgress: (Double) -> Void = { _ in }
    
    public init(
        from path: String,
        stopSequence: String? = nil,
        history: [Chat] = [],
        seed: UInt32 = .random(in: .min ... .max),
        topK: Int32 = 40,
        topP: Float = 0.95,
        temp: Float = 0.8,
        historyLimit: Int = 8,
        maxTokenCount: Int32 = 2048
    ) {
        self.path = path.cString(using: .utf8)!
        var modelParams = llama_model_default_params()
#if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
#endif
        let model = llama_load_model_from_file(self.path, modelParams)!
        params = llama_context_default_params()
        let processorCount = Int32(ProcessInfo().processorCount)
        self.maxTokenCount = Int(min(maxTokenCount, llama_n_ctx_train(model)))
        params.n_ctx = UInt32(self.maxTokenCount)
        params.n_batch = params.n_ctx
        params.n_threads = processorCount
        params.n_threads_batch = processorCount
        self.seed = seed
        self.topK = topK
        self.topP = topP
        self.temp = temp
        self.historyLimit = historyLimit
        self.model = model
        self.history = history
        self.totalTokenCount = Int(llama_n_vocab(model))
        self.newlineToken = model.newLineToken
        self.stopSequence = stopSequence?.utf8CString
        self.stopSequenceLength = (self.stopSequence?.count ?? 1) - 1
        batch = llama_batch_init(Int32(self.maxTokenCount), 0, 1)
    }
    
    deinit {
        llama_free_model(model)
    }
    
    public convenience init(
        from url: URL,
        stopSequence: String? = nil,
        history: [Chat] = [],
        seed: UInt32 = .random(in: .min ... .max),
        topK: Int32 = 40,
        topP: Float = 0.95,
        temp: Float = 0.8,
        historyLimit: Int = 8,
        maxTokenCount: Int32 = 2048
    ) {
        self.init(
            from: url.path,
            stopSequence: stopSequence,
            history: history,
            seed: seed,
            topK: topK,
            topP: topP,
            temp: temp,
            historyLimit: historyLimit,
            maxTokenCount: maxTokenCount
        )
    }
    
    public convenience init(
        from huggingFaceModel: HuggingFaceModel,
        to url: URL = .documentsDirectory,
        as name: String? = nil,
        history: [Chat] = [],
        seed: UInt32 = .random(in: .min ... .max),
        topK: Int32 = 40,
        topP: Float = 0.95,
        temp: Float = 0.8,
        historyLimit: Int = 8,
        maxTokenCount: Int32 = 2048,
        updateProgress: @escaping (Double) -> Void = { print(String(format: "downloaded(%.2f%%)", $0 * 100)) }
    ) async throws {
        let url = try await huggingFaceModel.download(to: url, as: name) { progress in
            Task { await MainActor.run { updateProgress(progress) } }
        }
        self.init(
            from: url,
            template: huggingFaceModel.template,
            history: history,
            seed: seed,
            topK: topK,
            topP: topP,
            temp: temp,
            historyLimit: historyLimit,
            maxTokenCount: maxTokenCount
        )
        self.updateProgress = updateProgress
    }
    
    public convenience init(
        from url: URL,
        template: Template,
        history: [Chat] = [],
        seed: UInt32 = .random(in: .min ... .max),
        topK: Int32 = 40,
        topP: Float = 0.95,
        temp: Float = 0.8,
        historyLimit: Int = 8,
        maxTokenCount: Int32 = 2048
    ) {
        self.init(
            from: url.path,
            stopSequence: template.stopSequence,
            history: history,
            seed: seed,
            topK: topK,
            topP: topP,
            temp: temp,
            historyLimit: historyLimit,
            maxTokenCount: maxTokenCount
        )
        self.preprocess = template.preprocess
        self.template = template
    }
    
    private var shouldContinuePredicting = false
    public func stop() {
        shouldContinuePredicting = false
    }
    
    @InferenceActor
    private func predictNextToken() async -> Token {
        guard shouldContinuePredicting else { return model.endToken }
        let samplerParams = llama_sampler_chain_default_params()
        let sampler = llama_sampler_chain_init(samplerParams)
        
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(topK))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(topP, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(temp))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(seed))

        let i = batch.n_tokens - 1
        let token = llama_sampler_sample(sampler, context.pointer, i)
        
        batch.clear()
        batch.add(token, currentCount, [0], true)
        context.decode(batch)
        return token
    }
    
    private var currentCount: Int32!
    private var decoded = ""
    
    open func recoverFromLengthy(_ input: borrowing String, to output:  borrowing AsyncStream<String>.Continuation) {
        output.yield("tl;dr")
    }
    
    private func prepare(from input: borrowing String, to output: borrowing AsyncStream<String>.Continuation) -> Bool {
        guard !input.isEmpty else { return false }
        context = .init(model, params)
        var tokens = encode(input)
        var initialCount = tokens.count
        currentCount = Int32(initialCount)
        if maxTokenCount <= currentCount {
            while !history.isEmpty && maxTokenCount <= currentCount {
                history.removeFirst(min(2, history.count))
                tokens = encode(preprocess(self.input, history))
                initialCount = tokens.count
                currentCount = Int32(initialCount)
            }
            if maxTokenCount <= currentCount {
                isFull = true
                recoverFromLengthy(input, to: output)
                return false
            }
        }
        for (i, token) in tokens.enumerated() {
            batch.n_tokens = Int32(i)
            batch.add(token, batch.n_tokens, [0], i == initialCount - 1)
        }
        context.decode(batch)
        shouldContinuePredicting = true
        return true
    }
    
    @InferenceActor
    private func finishResponse(from response: inout [String], to output: borrowing AsyncStream<String>.Continuation) async {
        multibyteCharacter.removeAll()
        var input = ""
        if !history.isEmpty {
            history.removeFirst(min(2, history.count))
            input = preprocess(self.input, history)
        } else {
            response.scoup(response.count / 3)
            input = preprocess(self.input, history)
            input += response.joined()
        }
        let rest = getResponse(from: input)
        for await restDelta in rest {
            output.yield(restDelta)
        }
    }
    
    private func process(_ token: Token, to output: borrowing AsyncStream<String>.Continuation) -> Bool {
        struct saved {
            static var stopSequenceEndIndex = 0
            static var letters: [CChar] = []
        }
        guard token != model.endToken else { return false }
        var word = decode(token)
        guard let stopSequence else { output.yield(word); return true }
        var found = 0 < saved.stopSequenceEndIndex
        var letters: [CChar] = []
        for letter in word.utf8CString {
            guard letter != 0 else { break }
            if letter == stopSequence[saved.stopSequenceEndIndex] {
                saved.stopSequenceEndIndex += 1
                found = true
                saved.letters.append(letter)
                guard saved.stopSequenceEndIndex == stopSequenceLength else { continue }
                saved.stopSequenceEndIndex = 0
                saved.letters.removeAll()
                return false
            } else if found {
                saved.stopSequenceEndIndex = 0
                if !saved.letters.isEmpty {
                    word = String(cString: saved.letters + [0]) + word
                    saved.letters.removeAll()
                }
                output.yield(word)
                return true
            }
            letters.append(letter)
        }
        if !letters.isEmpty { output.yield(found ? String(cString: letters + [0]) : word) }
        return true
    }
    
    private func getResponse(from input: String) -> AsyncStream<String> {
        .init { output in Task {
            defer { context = nil }
            guard prepare(from: input, to: output) else { return output.finish() }
            var response: [String] = []
            while currentCount < maxTokenCount {
                let token = await predictNextToken()
                if !process(token, to: output) { return output.finish() }
                currentCount += 1
            }
            await finishResponse(from: &response, to: output)
            return output.finish()
        } }
    }
    
    private var input: String = ""
    private var isAvailable = true
    
    @InferenceActor
    public func getCompletion(from input: borrowing String) async -> String {
        guard isAvailable else { fatalError("LLM is being used") }
        isAvailable = false
        let response = getResponse(from: input)
        var output = ""
        for await responseDelta in response {
            output += responseDelta
        }
        isAvailable = true
        return output
    }
    
    @InferenceActor
    public func respond(to input: String, with makeOutputFrom: @escaping (AsyncStream<String>) async -> String) async {
        guard isAvailable else { return }
        isAvailable = false
        self.input = input
        let processedInput = preprocess(input, history)
        let response = getResponse(from: processedInput)
        let output = await makeOutputFrom(response)
        history += [(.user, input), (.bot, output)]
        let historyCount = history.count
        if historyLimit < historyCount {
            history.removeFirst(min(2, historyCount))
        }
        postprocess(output)
        isAvailable = true
    }
    
    open func respond(to input: String) async {
        await respond(to: input) { [self] response in
            await setOutput(to: "")
            for await responseDelta in response {
                update(responseDelta)
                await setOutput(to: output + responseDelta)
            }
            update(nil)
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            await setOutput(to: trimmedOutput.isEmpty ? "..." : trimmedOutput)
            return output
        }
    }

    private var multibyteCharacter: [CUnsignedChar] = []
    private func decode(_ token: Token) -> String {
        return model.decode(token, with: &multibyteCharacter)
    }
    
    public func decode(_ tokens: [Token]) -> String {
        return tokens.map({model.decodeOnly($0)}).joined()
    }
    
    @inlinable
    public func encode(_ text: borrowing String) -> [Token] {
        model.encode(text)
    }
}

extension Model {
    public var endToken: Token { llama_token_eos(self) }
    public var newLineToken: Token { llama_token_nl(self) }
    
    public func shouldAddBOS() -> Bool {
        let addBOS = llama_add_bos_token(self);
        guard !addBOS else {
            return llama_vocab_type(self) == LLAMA_VOCAB_TYPE_SPM
        }
        return addBOS
    }
    
    public func decodeOnly(_ token: Token) -> String {
        var nothing: [CUnsignedChar] = []
        return decode(token, with: &nothing)
    }
    
    public func decode(_ token: Token, with multibyteCharacter: inout [CUnsignedChar]) -> String {
        var bufferLength = 16
        var buffer: [CChar] = .init(repeating: 0, count: bufferLength)
        let actualLength = Int(llama_token_to_piece(self, token, &buffer, Int32(bufferLength), 0, false))
        guard 0 != actualLength else { return "" }
        if actualLength < 0 {
            bufferLength = -actualLength
            buffer = .init(repeating: 0, count: bufferLength)
            llama_token_to_piece(self, token, &buffer, Int32(bufferLength), 0, false)
        } else {
            buffer.removeLast(bufferLength - actualLength)
        }
        if multibyteCharacter.isEmpty, let decoded = String(cString: buffer + [0], encoding: .utf8) {
            return decoded
        }
        multibyteCharacter.append(contentsOf: buffer.map { CUnsignedChar(bitPattern: $0) })
        guard let decoded = String(data: .init(multibyteCharacter), encoding: .utf8) else { return "" }
        multibyteCharacter.removeAll(keepingCapacity: true)
        return decoded
    }

    public func encode(_ text: borrowing String) -> [Token] {
        let addBOS = true
        let count = Int32(text.cString(using: .utf8)!.count)
        var tokenCount = count + 1
        let cTokens = UnsafeMutablePointer<llama_token>.allocate(capacity: Int(tokenCount)); defer { cTokens.deallocate() }
        tokenCount = llama_tokenize(self, text, count, cTokens, tokenCount, addBOS, false)
        let tokens = (0..<Int(tokenCount)).map { cTokens[$0] }
        return tokens
    }
}

private class Context {
    let pointer: OpaquePointer
    init(_ model: Model, _ params: llama_context_params) {
        self.pointer = llama_new_context_with_model(model, params)
    }
    deinit {
        llama_free(pointer)
    }
    func decode(_ batch: llama_batch) {
        guard llama_decode(pointer, batch) == 0 else { fatalError("llama_decode failed") }
    }
}

extension llama_batch {
    mutating func clear() {
        self.n_tokens = 0
    }
    
    mutating func add(_ token: Token, _ position: Int32, _ ids: [Int], _ logit: Bool) {
        let i = Int(self.n_tokens)
        self.token[i] = token
        self.pos[i] = position
        self.n_seq_id[i] = Int32(ids.count)
        if let seq_id = self.seq_id[i] {
            for (j, id) in ids.enumerated() {
                seq_id[j] = Int32(id)
            }
        }
        self.logits[i] = logit ? 1 : 0
        self.n_tokens += 1
    }
}

extension [String] {
    mutating func scoup(_ count: Int) {
        guard 0 < count else { return }
        let firstIndex = count
        let lastIndex = count * 2
        self.removeSubrange(firstIndex..<lastIndex)
    }
}

extension Token {
    enum Kind {
        case end
        case couldBeEnd
        case normal
    }
}

public enum Role {
    case user
    case bot
}

public struct Template {
    public typealias Attachment = (prefix: String, suffix: String)
    public let system: Attachment
    public let user: Attachment
    public let bot: Attachment
    public let systemPrompt: String?
    public let stopSequence: String?
    public let prefix: String
    public let shouldDropLast: Bool
    
    public init(
        prefix: String = "",
        system: Attachment? = nil,
        user: Attachment? = nil,
        bot: Attachment? = nil,
        stopSequence: String? = nil,
        systemPrompt: String?,
        shouldDropLast: Bool = false
    ) {
        self.system = system ?? ("", "")
        self.user = user  ?? ("", "")
        self.bot = bot ?? ("", "")
        self.stopSequence = stopSequence
        self.systemPrompt = systemPrompt
        self.prefix = prefix
        self.shouldDropLast = shouldDropLast
    }
    
    public var preprocess: (_ input: String, _ history: [Chat]) -> String {
        return { [self] input, history in
            var processed = prefix
            if let systemPrompt {
                processed += "\(system.prefix)\(systemPrompt)\(system.suffix)"
            }
            for chat in history {
                if chat.role == .user {
                    processed += "\(user.prefix)\(chat.content)\(user.suffix)"
                } else {
                    processed += "\(bot.prefix)\(chat.content)\(bot.suffix)"
                }
            }
            processed += "\(user.prefix)\(input)\(user.suffix)"
            if shouldDropLast {
                processed += bot.prefix.dropLast()
            } else {
                processed += bot.prefix
            }
            return processed
        }
    }
    
    public static func chatML(_ systemPrompt: String? = nil) -> Template {
        return Template(
            system: ("<|im_start|>system\n", "<|im_end|>\n"),
            user: ("<|im_start|>user\n", "<|im_end|>\n"),
            bot: ("<|im_start|>assistant\n", "<|im_end|>\n"),
            stopSequence: "<|im_end|>",
            systemPrompt: systemPrompt
        )
    }
    
    public static func alpaca(_ systemPrompt: String? = nil) -> Template {
        return Template(
            system: ("", "\n\n"),
            user: ("### Instruction:\n", "\n\n"),
            bot: ("### Response:\n", "\n\n"),
            stopSequence: "###",
            systemPrompt: systemPrompt
        )
    }
    
    public static func llama(_ systemPrompt: String? = nil) -> Template {
        return Template(
            prefix: "[INST] ",
            system: ("<<SYS>>\n", "\n<</SYS>>\n\n"),
            user: ("", " [/INST]"),
            bot: (" ", "</s><s>[INST] "),
            stopSequence: "</s>",
            systemPrompt: systemPrompt,
            shouldDropLast: true
        )
    }
    
    public static let mistral = Template(
        user: ("[INST] ", " [/INST]"),
        bot: ("", "</s> "),
        stopSequence: "</s>",
        systemPrompt: nil
    )
}

public enum Quantization: String {
    case IQ1_S
    case IQ1_M
    case IQ2_XXS
    case IQ2_XS
    case IQ2_S
    case IQ2_M
    case Q2_K_S
    case Q2_K
    case IQ3_XXS
    case IQ3_XS
    case IQ3_S
    case IQ3_M
    case Q3_K_S
    case Q3_K_M
    case Q3_K_L
    case IQ4_XS
    case IQ4_NL
    case Q4_0
    case Q4_1
    case Q4_K_S
    case Q4_K_M
    case Q5_0
    case Q5_1
    case Q5_K_S
    case Q5_K_M
    case Q6_K
    case Q8_0
}

public enum HuggingFaceError: Error {
    case network(statusCode: Int)
    case noFilteredURL
    case urlIsNilForSomeReason
}

public struct HuggingFaceModel {
    public let name: String
    public let template: Template
    public let filterRegexPattern: String
    
    public init(_ name: String, template: Template, filterRegexPattern: String) {
        self.name = name
        self.template = template
        self.filterRegexPattern = filterRegexPattern
    }
    
    public init(_ name: String, _ quantization: Quantization = .Q4_K_M, template: Template) {
        self.name = name
        self.template = template
        self.filterRegexPattern = "(?i)\(quantization.rawValue)"
    }
    
    public func getDownloadURLStrings() async throws -> [String] {
        let url = URL(string: "https://huggingface.co/\(name)/tree/main")!
        let data = try await url.getData()
        let content = String(data: data, encoding: .utf8)!
        let downloadURLPattern = #"(?<=href=").*\.gguf\?download=true"#
        let matches = try! downloadURLPattern.matches(in: content)
        let root = "https://huggingface.co"
        return matches.map { match in root + match }
    }

    public func getDownloadURL() async throws -> URL? {
        let urlStrings = try await getDownloadURLStrings()
        for urlString in urlStrings {
            let found = try filterRegexPattern.hasMatch(in: urlString)
            if found { return URL(string: urlString)! }
        }
        return nil
    }
    
    public func download(to directory: URL = .documentsDirectory, as name: String? = nil, _ updateProgress: @escaping (Double) -> Void) async throws -> URL {
        var destination: URL
        if let name {
            destination = directory.appending(path: name)
            guard !destination.exists else { updateProgress(1); return destination }
        }
        guard let downloadURL = try await getDownloadURL() else { throw HuggingFaceError.noFilteredURL }
        destination = directory.appending(path: downloadURL.lastPathComponent)
        guard !destination.exists else { return destination }
        try await downloadURL.downloadData(to: destination, updateProgress)
        return destination
    }
    
    public static func tinyLLaMA(_ quantization: Quantization = .Q4_K_M, _ systemPrompt: String) -> HuggingFaceModel {
        HuggingFaceModel("TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF", quantization, template: .chatML(systemPrompt))
    }
}

extension URL {
    @backDeployed(before: iOS 16)
    public func appending(path: String) -> URL {
        appendingPathComponent(path)
    }
    @backDeployed(before: iOS 16)
    public static var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    fileprivate var exists: Bool { FileManager.default.fileExists(atPath: path) }
    fileprivate func getData() async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: self)
        let statusCode = (response as! HTTPURLResponse).statusCode
        guard statusCode / 100 == 2 else { throw HuggingFaceError.network(statusCode: statusCode) }
        return data
    }
    fileprivate func downloadData(to destination: URL, _ updateProgress: @escaping (Double) -> Void) async throws {
        var observation: NSKeyValueObservation!
        let url: URL = try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: self) { url, response, error in
                if let error { return continuation.resume(throwing: error) }
                guard let url else { return continuation.resume(throwing: HuggingFaceError.urlIsNilForSomeReason) }
                let statusCode = (response as! HTTPURLResponse).statusCode
                guard statusCode / 100 == 2 else { return continuation.resume(throwing: HuggingFaceError.network(statusCode: statusCode)) }
                continuation.resume(returning: url)
            }
            observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                updateProgress(progress.fractionCompleted)
            }
            task.resume()
        }
        _ = observation
        try FileManager.default.moveItem(at: url, to: destination)
    }
}

public extension String {
    func matches(in content: String) throws -> [String] {
        let pattern = try NSRegularExpression(pattern: self)
        let range = NSRange(location: 0, length: content.utf16.count)
        let matches = pattern.matches(in: content, range: range)
        return matches.map { match in String(content[Range(match.range, in: content)!]) }
    }
    func hasMatch(in content: String) throws -> Bool {
        let pattern = try NSRegularExpression(pattern: self)
        let range = NSRange(location: 0, length: content.utf16.count)
        return pattern.firstMatch(in: content, range: range) != nil
    }
    func firstMatch(in content: String) throws -> String? {
        let pattern = try NSRegularExpression(pattern: self)
        let range = NSRange(location: 0, length: content.utf16.count)
        guard let match = pattern.firstMatch(in: content, range: range) else { return nil }
        return String(content[Range(match.range, in: content)!])
    }
}
