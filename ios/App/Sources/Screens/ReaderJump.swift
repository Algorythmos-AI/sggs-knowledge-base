import SwiftUI
import UIKit
import GurbaniSearchKit

/// Jump to Ang — a premium, elder-friendly navigator for the whole Granth.
///
/// The big number is a real, editable field seeded with the current Ang: tap it and the whole
/// number selects, so a new Ang replaces it in one keystroke — or place the cursor and edit a
/// single digit / backspace. The location line, scrubber, steppers, raag menu and the Go label
/// always agree. The primary action is pinned to the bottom, full-width, opaque, and restates the
/// destination ("Go to Ang 89"). Display/navigation only — no scripture is shown or changed here.
struct JumpToAngSheet: View {
    let current: Int
    /// Opened from the Reader's "Ang N" title: the reader wants to TYPE a number, so the keypad is
    /// up at once (sheet at full height so Go stays visible above it). Other openers leave it down.
    var focusField = false
    var onGo: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The committed destination (scrubber / steppers / raag). While the field is focused the reader
    /// may be part-way through typing a different number — `effectiveTarget` prefers what's typed, so
    /// Go and the location line follow the keypad without the scrubber lurching on every digit.
    @State private var target: Int
    /// The number field's text — seeded with the Ang so it is genuinely editable (retype after a
    /// select-all, or edit a digit / backspace). Mirrors `target` whenever the field is not focused.
    @State private var text: String
    @FocusState private var fieldFocused: Bool
    @State private var detent: PresentationDetent = .fraction(0.65)

    private let bounds = 1...1430

    init(current: Int, focusField: Bool = false, onGo: @escaping (Int) -> Void) {
        self.current = current
        self.focusField = focusField
        self.onGo = onGo
        _target = State(initialValue: current)
        _text = State(initialValue: String(current))
    }

    /// The typed number when it is a valid Ang, else nil (empty, non-numeric, or out of range).
    private var typedAng: Int? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, let n = Int(t), bounds.contains(n) else { return nil }
        return n
    }
    private var invalidTyped: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && typedAng == nil
    }
    /// A valid typed value wins; otherwise the committed target.
    private var effectiveTarget: Int { typedAng ?? target }
    private var canGo: Bool { !invalidTyped && effectiveTarget != current }
    private var location: AngLocator.Location? { AngLocator.location(for: effectiveTarget, meta: container.meta) }

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
                // "Done" only dismisses the keypad (not the sheet), so the reader can still fine-tune
                // with the scrubber/steppers before Go. The single Go is the pinned bar below — there
                // is no duplicate keyboard Go to crowd it or overlap the raag card.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                }
            }
            .safeAreaInset(edge: .bottom) { goBar }
            .task { await container.loadMeta() }          // idempotent; fills raag ticks + location
            // Steppers / scrubber / raag move `target` → keep the field showing it, but never while
            // the reader is mid-type (that would overwrite their digits).
            .onChange(of: target) { _, v in if !fieldFocused { text = String(v) } }
            .onChange(of: fieldFocused) { _, focused in
                if focused {
                    // select the whole number so the first digit replaces it; backspace still edits
                    DispatchQueue.main.async {
                        UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                    }
                } else {
                    if let n = typedAng { target = n }     // commit a valid entry (aligns the scrubber)
                    text = String(target)                  // normalise (revert an empty / invalid entry)
                }
            }
            .onChange(of: typeSize) { _, size in if size.isAccessibilitySize { detent = .large } }
            .onAppear { if typeSize.isAccessibilitySize { detent = .large } }
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

    // MARK: hero — the big number is a real, editable field

    private var hero: some View {
        VStack(spacing: Theme.Space.s) {
            Text("Ang").font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary).textCase(.uppercase).tracking(1)

            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(Brand.heading(.largeTitle, weight: 700))
                .monospacedDigit()
                .foregroundStyle(invalidTyped ? Ink.negative : Color.primary)
                .focused($fieldFocused)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .accessibilityIdentifier("angField")
                .accessibilityLabel("Ang number")
                .accessibilityValue(String(effectiveTarget))
                .accessibilityHint("Edit the number to any Ang from 1 to 1430")
                // pencil affordance so the number reads as editable, not a static label
                .overlay(alignment: .trailing) {
                    if !fieldFocused {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3).foregroundStyle(.secondary)
                            .padding(.trailing, Theme.Space.l)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                // a quiet underline that says "this is a field", brightening when focused
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(fieldFocused ? Color.accentColor : Ink.hairline)
                        .frame(width: 140, height: 2)
                        .offset(y: 8)
                        .accessibilityHidden(true)
                }

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
        .disabled(delta < 0 ? effectiveTarget <= bounds.lowerBound : effectiveTarget >= bounds.upperBound)
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

    // MARK: pinned primary action — one opaque bar, above the keypad, never see-through

    private var goBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Ink.hairline)
            Button { go() } label: {
                Text(canGo ? "Go to Ang \(effectiveTarget)"
                           : (invalidTyped ? "Enter an Ang from 1 to 1430" : "You're on Ang \(current)"))
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.prominentPill)
            .disabled(!canGo)
            .opacity(canGo ? 1 : 0.5)          // an honest, clearly-inactive look when there's nowhere to go
            .accessibilityIdentifier("goToAng")
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.s)
            .padding(.bottom, Theme.Space.s)
        }
        .background(Ink.canvas)   // opaque: the raag card can never bleed through the bar
    }

    // MARK: actions

    private func go() {
        guard canGo else { return }
        Haptics.success()
        fieldFocused = false
        onGo(effectiveTarget)
        dismiss()
    }

    /// Nudge from whatever is showing now (typed value included), so ±1 after typing is exact.
    private func nudge(_ delta: Int) {
        Haptics.tap()
        setTarget(effectiveTarget + delta)
    }

    /// Set the destination from a control; dismiss the keypad and show the value in the field.
    private func setTarget(_ v: Int) {
        let clamped = min(max(bounds.lowerBound, v), bounds.upperBound)
        fieldFocused = false
        target = clamped
        text = String(clamped)
    }
}
