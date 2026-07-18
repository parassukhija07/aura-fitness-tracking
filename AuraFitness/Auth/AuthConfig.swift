import Foundation

/// Reads the Supabase project URL + anon key from Info.plist, which in turn
/// are injected from `Secrets.xcconfig` (git-ignored — see
/// `Secrets.xcconfig.template` for the keys to fill in). No literals here.
///
/// Mechanism (verified against this project's `project.pbxproj`): the
/// `AuraFitness` target has `GENERATE_INFOPLIST_FILE = YES` on both Debug and
/// Release, which is the documented precondition for Xcode's generic
/// `INFOPLIST_KEY_<Name>` build-setting passthrough (Xcode 13+) — any build
/// setting named `INFOPLIST_KEY_Foo` is lifted verbatim into a top-level
/// `Foo` string entry of the synthesized Info.plist at build time, not just
/// Apple's own known keys. `INFOPLIST_KEY_SUPABASE_URL = $(SUPABASE_URL)` and
/// `INFOPLIST_KEY_SUPABASE_ANON_KEY = $(SUPABASE_ANON_KEY)` are present in
/// both build configs; `$(SUPABASE_URL)`/`$(SUPABASE_ANON_KEY)` in turn only
/// resolve once `Secrets.xcconfig` is wired as the target's "Based on
/// Configuration File" (see Secrets.xcconfig.template + changes.md manual
/// steps) — until then they resolve to empty strings, which is exactly what
/// trips the guards below.
enum AuthConfig {
    static var supabaseURL: URL = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !raw.isEmpty,
              let url = URL(string: raw) else {
            #if DEBUG
            fatalError("""
                Missing/invalid SUPABASE_URL in Info.plist.
                1) Create AuraFitness/Secrets.xcconfig (see Secrets.xcconfig.template) \
                with SUPABASE_URL = https://<project-ref>.supabase.co.
                2) In Xcode: Project > AuraFitness (project) > Info tab > Configurations > \
                set both Debug and Release "Based on Configuration File" to Secrets.xcconfig \
                for the AuraFitness target.
                3) Confirm the target's build settings still have \
                INFOPLIST_KEY_SUPABASE_URL = $(SUPABASE_URL) and GENERATE_INFOPLIST_FILE = YES \
                (both already present in project.pbxproj as shipped).
                """)
            #else
            // Non-crashing gate in RELEASE: fall back to an obviously-invalid
            // placeholder so ConfigErrorGate can detect and surface it instead
            // of crashing a shipped build.
            return URL(string: "https://missing-config.invalid")!
            #endif
        }()
        return url
    }()

    static var supabaseAnonKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            #if DEBUG
            fatalError("""
                Missing SUPABASE_ANON_KEY in Info.plist.
                1) Create AuraFitness/Secrets.xcconfig (see Secrets.xcconfig.template) \
                with SUPABASE_ANON_KEY = <anon key>.
                2) In Xcode: Project > AuraFitness (project) > Info tab > Configurations > \
                set both Debug and Release "Based on Configuration File" to Secrets.xcconfig \
                for the AuraFitness target.
                3) Confirm the target's build settings still have \
                INFOPLIST_KEY_SUPABASE_ANON_KEY = $(SUPABASE_ANON_KEY) and \
                GENERATE_INFOPLIST_FILE = YES (both already present in project.pbxproj as shipped).
                """)
            #else
            return ""
            #endif
        }()
        return key
    }()

    /// True when the RELEASE non-crashing fallback values are in effect —
    /// used to gate the UI behind a config-error screen instead of making
    /// network calls with garbage credentials.
    static var isConfigured: Bool {
        supabaseURL.host != "missing-config.invalid" && !supabaseAnonKey.isEmpty
    }
}
