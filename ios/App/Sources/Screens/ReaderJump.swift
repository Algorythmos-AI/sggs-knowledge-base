import SwiftUI
import GurbaniSearchKit

/// Jump to Ang — a premium, elder-friendly navigator for the whole Granth.
///
/// One source of truth (`target`); the big number, the location line, the scrubber, the steppers,
/// the raag menu and the Go label always agree. An exact Ang is reachable three ways: type it,
/// scrub + nudge with the ±1 / ±10 steppers, or pick a raag. The primary action is pinned to the
/// bottom, full-width, and restates the destination ("Go to Ang 89"). Display/navigation only —
/// no scripture is shown or changed here.
struct JumpToAngSheet: View {
    let current: Int
    /// Opened from the Reader's "Ang N" title: the reader wants to TYPE a number, so the keypad is
    /// up at once (sheet at full height so Go stays visible above it). Other openers leave it down.
    var focusField = false
    var onGo: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The single destination the whole sheet edits.
    @State private var target: Int
    /// The number field's raw buffer. Empty ⇒ the hero shows `target`; typing overrides and,
    /// when valid, writes back into `target` (so scrubber and steppers follow what was typed).
    @State private var text = ""
    @FocusState private var fieldFocused: Bool
    @State private var detent: PresentationDetent = .fraction(0.65)

    private let bounds = 1...1430

    init(current: Int, focusField: Bool = false, onGo: @escaping (Int) -> Void) {
        self.current = current
        self.focusField = focusField
        self.onGo = onGo
        _target = State(initialValue: current)
    }

    private var typedAng: Int? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, let n = Int(t), bounds.contains(n) else { return nil }
        return n
    }
    private var invalidTyped: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && typedAng == nil
    }
    private var location: AngLocator.Location? { AngLocator.location(for: target, meta: container.meta) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.xl) {
                    hero
                    AngScrubber(value: $target,
                                bounds: bounds,
                                ticks: AngLocator.raagBoundaries(meta: container.meta))
                        .padding(.horizontal, Theme.Space.xs)
                    scrubberEndLabels
                    steppers
                    raagMenu
                }
                .padding(Theme.Space.l)
            }
            .background(Ink.canvas.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Jump to Ang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Go") { go() }.disabled(!canGo)
                }
            }
            .safeAreaInset(edge: .bottom) { goBar }
            .task { await container.loadMeta() }          // idempotent; fills raag ticks + location
            .onChange(of: text) { _, _ in if let n = typedAng { target = n } }
            // scrubber moved the destination out from under a stale typed buffer → clear it so the
            // hero and Go label follow the scrubber (typing keeps text, because it syncs target).
            .onChange(of: target) { _, v in if typedAng != v { text = "" } }
            .onChange(of: typeSize) { _, size in if size.isAccessibilitySize { detent = .large } }
            .onAppear { if typeSize.isAccessibilitySize || focusField { detent = .large } }
            .task {
                guard focusField else { return }
                // focus after the sheet has presented — a focus request during the transition is dropped
                try? await Task.sleep(for: .milliseconds(350))
                if !Task.isCancelled { fieldFocused = true }
            }
        }
        .presentationDetents([.fraction(0.65), .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    // MARK: hero — the big number IS the text field

    private var hero: some View {
        VStack(spacing: Theme.Space.s) {
            Text("Ang").font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary).textCase(.uppercase).tracking(1)
            ZStack {
                // the live destination, shown when nothing is being typed
                Text(String(target))
                    .foregroundStyle(text.isEmpty ? Color.primary : Color.clear)
                    .contentTransition(.numericText())
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                // the actual input; transparent text while empty so the label above shows through
                TextField("", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(text.isEmpty ? Color.clear : Color.primary)
                    .focused($fieldFocused)
                    .accessibilityIdentifier("angField")
                    .accessibilityLabel("Ang number")
                    .accessibilityValue(String(target))
            }
            .font(Brand.heading(.largeTitle, weight: 700))
            .monospacedDigit()
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { fieldFocused = true }

            if invalidTyped {
                Text("Enter an Ang between 1 and 1430.")
                    .font(.footnote).foregroundStyle(Ink.negative)
            } else if let loc = location {
                locationLine(loc)
            } else {
                Text("of 1430").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func locationLine(_ loc: AngLocator.Location) -> some View {
        (
            Text(loc.gurmukhi.map { "\($0)  " } ?? "").foregroundColor(.primary)
            + Text([loc.roman, loc.rangeLabel].compactMap { $0 }.joined(separator: " · "))
                .foregroundColor(.secondary)
        )
        .font(.footnote)
        .multilineTextAlignment(.center)
        .accessibilityLabel("In \(loc.roman ?? loc.gurmukhi ?? "the Granth"), \(loc.rangeLabel)")
    }

    private var scrubberEndLabels: some View {
        HStack {
            Text("1").foregroundStyle(.secondary)
            Spacer()
            Text("1430").foregroundStyle(.secondary)
        }
        .font(.caption).monospacedDigit()
        .accessibilityHidden(true)
    }

    // MARK: fine-tune steppers — reach any exact Ang without typing

    private var steppers: some View {
        HStack(spacing: Theme.Space.s) {
            stepButton(-10)
            stepButton(-1)
            stepButton(+1)
            stepButton(+10)
        }
    }

    private func stepButton(_ delta: Int) -> some View {
        Button {
            nudge(delta)
        } label: {
            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                .font(.headline.weight(.semibold)).monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Ink.card, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).strokeBorder(Ink.hairline))
        }
        .buttonStyle(.pressableCard)
        .buttonRepeatBehavior(.enabled)
        .disabled(delta < 0 ? target <= bounds.lowerBound : target >= bounds.upperBound)
        .accessibilityLabel(delta > 0 ? "Forward \(delta)" : "Back \(-delta)")
    }

    // MARK: raag jump

    private var raagMenu: some View {
        Menu {
            ForEach(container.meta?.raags ?? []) { r in
                Button {
                    setTarget(r.firstAng)
                } label: {
                    Text([r.roman, r.name].compactMap { $0 }.first ?? r.name) + Text("  ·  Ang \(r.firstAng)")
                }
            }
            if let sections = container.meta?.sections, !sections.isEmpty {
                Divider()
                ForEach(sections) { s in
                    Button { setTarget(s.firstAng) } label: { Text("\(s.name)  ·  Ang \(s.firstAng)") }
                }
            }
        } label: {
            HStack {
                Label("Jump to a raag", systemImage: "music.note.list")
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Theme.Space.l)
            .background(Ink.card, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).strokeBorder(Ink.hairline))
        }
        .disabled((container.meta?.raags ?? []).isEmpty)
    }

    // MARK: pinned primary action

    private var goBar: some View {
        Button { go() } label: {
            Text(target == current ? "You're on Ang \(current)" : "Go to Ang \(target)")
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.prominentPill)
        .disabled(!canGo)
        .accessibilityIdentifier("goToAng")
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.s)
        .background(.ultraThinMaterial)
    }

    // MARK: actions

    private var canGo: Bool { !invalidTyped && effectiveTarget != current }
    /// A valid typed value wins; otherwise the shared `target`.
    private var effectiveTarget: Int { typedAng ?? target }

    private func go() {
        guard canGo else { return }
        Haptics.success()
        onGo(effectiveTarget)
        dismiss()
    }

    private func nudge(_ delta: Int) {
        Haptics.tap()
        setTarget(target + delta)
    }

    /// Set the destination from a control and clear the typed buffer so the hero shows it.
    private func setTarget(_ v: Int) {
        target = min(max(bounds.lowerBound, v), bounds.upperBound)
        text = ""
        fieldFocused = false
    }
}
