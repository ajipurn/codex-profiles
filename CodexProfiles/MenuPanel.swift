import SwiftUI
import CodexProfilesCore

struct MenuPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var searchFocused: Bool
    @State private var profilePendingDelete: Profile?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleBar
                    header
                    feedback
                    if model.editor != nil {
                        nameEditor
                    }
                    accountsSection
                }
                .padding(18)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: panelContentHeight)

            footer
        }
        .frame(width: 420)
        .background(.regularMaterial)
        .onAppear {
            model.refresh()
            model.startLiveUsagePolling()
        }
        .onDisappear {
            model.stopLiveUsagePolling()
        }
        .background {
            Button("Find account") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
        .onChange(of: model.editor) { _, editor in
            nameFieldFocused = editor != nil
        }
        .confirmationDialog(
            "Remove saved account?",
            isPresented: Binding(
                get: { profilePendingDelete != nil },
                set: { if !$0 { profilePendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove saved account", role: .destructive) {
                if let profilePendingDelete {
                    model.delete(profilePendingDelete)
                }
                profilePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                profilePendingDelete = nil
            }
        } message: {
            if profilePendingDelete?.id == model.live?.matchingProfileID {
                Text("This removes the saved profile. You’ll remain signed in to the account.")
            } else {
                Text("You won’t be able to switch back without signing in again.")
            }
        }
    }

    private var panelContentHeight: CGFloat {
        let quotaHeight = model.live?.file?.isChatGPTSession == true ? 190 : 30
        let rowsHeight = model.profiles.isEmpty || model.visibleProfiles.isEmpty
            ? 175 : 50 + model.visibleProfiles.count * (model.settings.hideEmails ? 64 : 78)
        let editorHeight = model.editor == nil ? 0 : 190
        let feedbackHeight = (model.error != nil && model.editor == nil)
            || (model.status != nil && (model.isBusy || model.awaitingLogin)) ? 58 : 0
        return min(620, CGFloat(180 + quotaHeight + rowsHeight + editorHeight + feedbackHeight))
    }

    private var titleBar: some View {
        HStack {
            Label("Codex Profiles", systemImage: "person.crop.rectangle.stack")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button {
                model.settings.hideEmails.toggle()
                model.updateSettings()
            } label: {
                Image(systemName: model.settings.hideEmails ? "eye.slash" : "eye")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .help(model.settings.hideEmails ? "Show email addresses" : "Hide email addresses")
            .accessibilityLabel(model.settings.hideEmails ? "Show email addresses" : "Hide email addresses")
            .disabled(model.isBusy || model.pendingNewLogin)
        }
        .foregroundStyle(.secondary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT ACCOUNT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 11) {
                initialsBadge(
                    initials: model.live?.identity?.initials ?? "–",
                    size: 38,
                    emphasized: true
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.currentTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .help(model.currentTitle)
                    Text(model.currentSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if model.live?.matchingProfileID != nil {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                } else if model.needsSave {
                    Text("Unsaved")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            if model.live?.file?.isChatGPTSession == true {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    UsageCard(state: model.liveUsage, now: context.date) {
                        model.refreshUsage(force: true)
                    }
                }
            } else if model.live?.identity?.authMode == "apikey" {
                Label("API key usage is billed separately.", systemImage: "key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor.opacity(0.055)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor.opacity(0.12), lineWidth: 1))
    }

    @ViewBuilder
    private var feedback: some View {
        if let error = model.error, model.editor == nil {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button {
                    model.dismissError()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.red.opacity(0.10))
            )
            .accessibilityElement(children: .contain)
        } else if let status = model.status, model.isBusy || model.awaitingLogin {
            HStack(spacing: 9) {
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                }
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if model.awaitingLogin {
                    Button("Cancel login") {
                        model.cancelLogin()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.medium))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
            .accessibilityElement(children: .contain)
        }
    }

    private var nameEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(editorTitle)
                    .font(.subheadline.weight(.semibold))
                Text(editorDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Account name")
                    .font(.caption.weight(.medium))
                TextField("For example, Work", text: Bindable(model).draftName)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFieldFocused)
                    .onSubmit { model.commitEditor() }

                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Error: \(error)")
                }
            }

            HStack(spacing: 8) {
                Button("Cancel") { model.cancelEditor() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(model.isBusy)
                Spacer()
                Button {
                    model.commitEditor()
                } label: {
                    HStack(spacing: 6) {
                        if model.isBusy {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(editorConfirmTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.isBusy || model.draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
    }

    private var editorTitle: String {
        switch model.editor {
        case .save: "Save this account"
        case .rename: "Rename account"
        case .add: "Finish adding account"
        case .none: ""
        }
    }

    private var editorDescription: String {
        switch model.editor {
        case .save:
            "Choose a name that makes this login easy to recognize."
        case .rename:
            "Choose how this account appears in the list."
        case .add:
            "Signed in as \(model.currentTitle). Choose how it appears in the list."
        case .none:
            ""
        }
    }

    private var editorConfirmTitle: String {
        switch model.editor {
        case .rename: "Save name"
        default: "Save account"
        }
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                Text("Accounts")
                    .font(.subheadline.weight(.semibold))
                if !model.profiles.isEmpty {
                    Text("\(model.profiles.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    model.beginAdd()
                } label: {
                    Label("Add account", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut("n", modifiers: .command)
                .disabled(model.isBusy || model.pendingNewLogin)
            }

            if !model.profiles.isEmpty {
                accountFilters
            }

            if model.needsSave, model.editor == nil {
                HStack(spacing: 9) {
                    Image(systemName: "bookmark")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("This login isn’t saved yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Save account") { model.beginSave() }
                        .disabled(model.isBusy || model.pendingNewLogin)
                        .buttonStyle(.borderless)
                        .font(.caption.weight(.medium))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.09))
                )
            }

            if model.profiles.isEmpty {
                emptyState
            } else if model.visibleProfiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: model.favoritesOnly ? "star" : "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(model.favoritesOnly && model.searchText.isEmpty ? "No favorite accounts yet" : "No matching accounts")
                        .font(.subheadline.weight(.medium))
                    Text(model.favoritesOnly ? "Star an account from its action menu, or show all accounts." : "Try another name, email, or workspace.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Show all accounts") {
                        model.searchText = ""
                        model.favoritesOnly = false
                    }
                    .buttonStyle(.borderless)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            } else {
                profileRows
            }
        }
    }

    private var accountFilters: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search accounts", text: Bindable(model).searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .accessibilityLabel("Search by account name, email, or workspace")
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.045)))

            Toggle(isOn: Bindable(model).favoritesOnly) {
                Image(systemName: model.favoritesOnly ? "star.fill" : "star")
            }
            .toggleStyle(.button)
            .tint(.orange)
            .help("Show favorites only")
            .accessibilityLabel("Show favorites only")

            Menu {
                Picker("Sort accounts", selection: setting(\.sortOrder)) {
                    ForEach(ProfileSortOrder.allCases, id: \.self) { order in
                        Text(order.title).tag(order)
                    }
                }
                Divider()
                Text("Active account and favorites stay on top")
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuIndicator(.hidden)
            .help("Sort: \(model.settings.sortOrder.title)")
            .accessibilityLabel("Sort accounts")
        }
        .font(.caption)
    }

    private var profileRows: some View {
        LazyVStack(spacing: 6) {
            ForEach(model.visibleProfiles) { profile in
                profileRow(profile)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: model.needsSave ? "bookmark" : "person.crop.circle.badge.plus")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(spacing: 3) {
                Text(model.needsSave ? "Save your first account" : "No saved accounts")
                    .font(.subheadline.weight(.medium))
                Text(model.needsSave
                     ? "Save this login so you can switch back to it later."
                     : "Add an account to switch logins without signing in each time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(model.needsSave ? "Save this account" : "Add your first account") {
                if model.needsSave {
                    model.beginSave()
                } else {
                    model.beginAdd()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(model.isBusy || model.pendingNewLogin)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }

    private func profileRow(_ profile: Profile) -> some View {
        let isActive = profile.id == model.live?.matchingProfileID
        let usageState = model.profileUsage[profile.id]

        return HStack(spacing: 6) {
            Button {
                model.switchTo(profile)
            } label: {
                HStack(spacing: 10) {
                    initialsBadge(
                        initials: profile.identity?.initials ?? "C",
                        size: 30,
                        emphasized: isActive
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(model.displayName(for: profile))
                                .font(.subheadline.weight(isActive ? .semibold : .regular))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if model.settings.favoriteProfileIDs.contains(profile.id) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                                    .accessibilityHidden(true)
                            }
                            if isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                        if !model.settings.hideEmails, let email = profile.identity?.email,
                           email != profile.displayName {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .help(email)
                        }
                        if let subtitle = profile.identity?.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .help(subtitle)
                        }
                    }

                    Spacer(minLength: 8)
                    UsageCompactLabel(state: usageState)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(profileAccessibilityLabel(profile, active: isActive))
            .accessibilityHint(isActive ? "Current account" : "Switch to this account")

            Menu {
                Button(model.settings.favoriteProfileIDs.contains(profile.id) ? "Remove from favorites" : "Add to favorites",
                       systemImage: model.settings.favoriteProfileIDs.contains(profile.id) ? "star.slash" : "star") {
                    model.toggleFavorite(profile)
                }
                Divider()
                if usageState?.error != nil {
                    Button("Sign in again…") { model.beginAdd() }
                    Divider()
                }
                Button("Rename…") { model.beginRename(profile) }
                Button("Remove saved account…", role: .destructive) {
                    profilePendingDelete = profile
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .accessibilityLabel("Actions for \(model.displayName(for: profile))")
            .help("Account actions")
        }
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.09) : Color.primary.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? Color.accentColor.opacity(0.16) : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            Button(model.settings.favoriteProfileIDs.contains(profile.id) ? "Remove from favorites" : "Add to favorites") {
                model.toggleFavorite(profile)
            }
            Button("Rename…") { model.beginRename(profile) }
            Button("Remove saved account…", role: .destructive) {
                profilePendingDelete = profile
            }
        }
        .disabled(model.isBusy || model.pendingNewLogin)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                model.refresh()
                model.refreshUsage(force: true)
            } label: {
                HStack(spacing: 6) {
                    if model.isRefreshingUsage {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(model.isRefreshingUsage ? "Refreshing…" : "Refresh")
                }
                .frame(minHeight: 24)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Refresh account usage")
            .keyboardShortcut("r", modifiers: .command)
            .disabled(model.isBusy || model.pendingNewLogin || model.isRefreshingUsage)

            if let checked = model.lastUsageCheck {
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text(checked, style: .relative)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .help("Last checked \(checked.formatted(date: .abbreviated, time: .standard))")
                        .accessibilityLabel("Last usage check \(checked.formatted())")
                }
            }
            Spacer()

            Menu {
                Toggle("Restart ChatGPT after switching", isOn: setting(\.restartChatGPT))
                Toggle("Refresh automatically every 2 minutes", isOn: setting(\.autoRefresh))
                Toggle("Show 5-hour remaining quota in menu bar", isOn: setting(\.showMenuBarUsage))
                Toggle("Hide email addresses", isOn: setting(\.hideEmails))
                Divider()
                if let updater = model.updater {
                    UpdateSettingsMenu(updater: updater)
                    Divider()
                }
                Text("Shortcuts: ⌘F Search · ⌘N Add · ⌘R Refresh")
                Divider()
                Button("Quit Codex Profiles") { model.quit() }
                    .keyboardShortcut("q", modifiers: .command)
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .frame(minHeight: 24)
            }
            .menuIndicator(.hidden)
            .accessibilityLabel("Codex Profiles settings")
            .disabled(model.isBusy || model.pendingNewLogin)
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.35)
        }
    }

    private func initialsBadge(
        initials: String,
        size: CGFloat,
        emphasized: Bool
    ) -> some View {
        ZStack {
            Circle()
                .fill(emphasized ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.065))
            Text(initials)
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(emphasized ? Color.accentColor : Color.primary.opacity(0.72))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func profileAccessibilityLabel(_ profile: Profile, active: Bool) -> String {
        let subtitle = profile.identity?.subtitle ?? ""
        let state = active ? "active account" : "saved account"
        return [model.displayName(for: profile), subtitle, state]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: {
                model.settings[keyPath: keyPath] = $0
                model.updateSettings()
            }
        )
    }
}
