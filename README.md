# OpenRouterDesktop

Native macOS chat client for [OpenRouter](https://openrouter.ai). SwiftUI, sandboxed, no third-party dependencies.

## Features

**Models**
- Browse OpenRouter's catalog with live search and family grouping
- "Free only" toggle in the picker (defaults on; flip off to see paid models too)
- Auto-retry on transient network errors (DNS, timeouts, dropped connections)

**Chat**
- Streaming responses (SSE) with a stop button
- Per-conversation system prompts and remembered model selection
- Edit a previous user message and regenerate from there
- Regenerate the last reply — click for the current model, or pick a different one from the disclosure menu
- Auto-naming new chats via a tiny summarization call

**Organization**
- Multiple conversations grouped into folders, with drag-and-drop between them
- Pin chats to keep them at the top
- Sidebar search with snippet preview + match highlighting
- Reusable prompt template library, inserted from the input bar

**System**
- Export any chat as Markdown
- API key stored in the macOS Keychain
- Cmd+N new chat, Cmd+Shift+N new folder, Cmd+[ / Cmd+] cycle chats, Cmd+Shift+K clear active chat

## Requirements

- macOS 14.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An OpenRouter API key — get one at <https://openrouter.ai/keys>

## Build & run

```sh
xcodegen generate
xcodebuild -project OpenRouterDesktop.xcodeproj -scheme OpenRouterDesktop -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/OpenRouterDesktop-*/Build/Products/Debug/OpenRouterDesktop.app
```

Or open `OpenRouterDesktop.xcodeproj` in Xcode and ⌘R.

On first launch, open Settings (⌘,) and paste your OpenRouter API key.

## Layout

```
OpenRouterDesktop/
├── App/                  # @main entry, AppConstants, AppDelegate
├── Models/               # Message, OpenRouterModel, Conversation, ChatFolder, PromptTemplate
├── Services/             # OpenRouterService (API), KeychainService, ConversationStore, PromptLibraryStore
├── ViewModels/           # ChatViewModel, ModelsViewModel, ConversationsViewModel, PromptLibraryViewModel
├── Views/                # ContentView, Sidebar, Chat, Settings, Prompts
└── OpenRouterDesktop.entitlements
project.yml               # XcodeGen source-of-truth
```

State is persisted to `~/Library/Containers/com.openrouter.desktop/Data/Library/Application Support/OpenRouterDesktop/`:

- `index.json` — folders + ordering
- `conversations/{uuid}.json` — one file per chat (messages, system prompt, model)
- `prompts.json` — prompt template library

If Application Support is unreachable at launch, the app falls back to the temp directory and logs a warning. Chats won't persist across launches in that mode, but the app stays usable.

## Notes

- The app sandbox is enabled. Only `network.client` and `files.user-selected.read-write` (for Markdown export via NSSavePanel) entitlements are granted.
- Token counts shown in the UI are heuristic (`max(chars/4, words·4/3)`), not real BPE — close enough for sizing decisions, not for billing.
- Response bodies are logged with `privacy: .private` (visible in Console.app only when device-debug logging is enabled).
