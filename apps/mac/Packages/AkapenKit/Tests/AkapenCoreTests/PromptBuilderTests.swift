import Foundation
import Testing
import AkapenCore

private func annotation(_ path: String, _ comment: String) -> Annotation {
    Annotation(
        imagePath: path,
        comment: comment,
        rect: ScreenRect(x: 10, y: 20, width: 30, height: 40),
        sourceAppName: "Sample App",
        createdAt: Date(timeIntervalSince1970: 0),
        windowFrame: ScreenRect(x: 0, y: 0, width: 100, height: 100)
    )
}

private let designAnnotations = [
    annotation("/Users/yuto/Library/Caches/akapen/20261117-1432/01.png", "ボタンの余白が左右で違う"),
    annotation("/Users/yuto/Library/Caches/akapen/20261117-1432/02.png", "ここの文言を「保存する」に"),
]

@Test
func promptMatchesDesignExample() {
    // DESIGN.md「コピーされるプロンプト」の例を、そのまま書き写したもの。
    let expected = """
        I annotated the screen. Please address the comments below.
        Open every image and check the area marked with the red frame before you start.

        /Users/yuto/Library/Caches/akapen/20261117-1432/01.png
        ボタンの余白が左右で違う

        /Users/yuto/Library/Caches/akapen/20261117-1432/02.png
        ここの文言を「保存する」に
        """
    let prompt = PromptBuilder.build(settings: Settings(), annotations: designAnnotations)
    #expect(prompt == expected)
    #expect(!prompt.hasSuffix("\n"))
}

@Test
func promptUsesJapaneseBoilerplate() {
    var settings = Settings()
    settings.language = .ja
    let prompt = PromptBuilder.build(settings: settings, annotations: [designAnnotations[0]])
    #expect(prompt == """
        画面に注釈を付けました。以下のコメントに対応してください。
        作業前にすべての画像を開き、赤枠の箇所を確認してください。

        /Users/yuto/Library/Caches/akapen/20261117-1432/01.png
        ボタンの余白が左右で違う
        """)
}

@Test
func promptKeepsCustomBoilerplateAcrossLanguages() {
    var settings = Settings()
    settings.setBoilerplate("見てください。", for: .ja)
    settings.setBoilerplate("Look at these.\n", for: .en)
    let english = PromptBuilder.build(settings: settings, annotations: [designAnnotations[1]])
    #expect(english == """
        Look at these.

        /Users/yuto/Library/Caches/akapen/20261117-1432/02.png
        ここの文言を「保存する」に
        """)
    settings.language = .ja
    let japanese = PromptBuilder.build(settings: settings, annotations: [designAnnotations[1]])
    #expect(japanese == english)
}

@Test
func promptKeepsMultilineComments() {
    let prompt = PromptBuilder.build(
        boilerplate: "Head",
        annotations: [annotation("/a/01.png", "1 行目\n2 行目")]
    )
    #expect(prompt == "Head\n\n/a/01.png\n1 行目\n2 行目")
}

@Test
func promptWithoutBoilerplateStartsWithFirstPath() {
    let prompt = PromptBuilder.build(boilerplate: " \n", annotations: [annotation("/a/01.png", "x")])
    #expect(prompt == "/a/01.png\nx")
}

@Test
func boilerplateFallsBackToDefaultPerLanguage() throws {
    #expect(Settings().boilerplate(for: .en) == Boilerplate.english)
    #expect(Settings().boilerplate(for: .ja) == Boilerplate.japanese)
    // 書き換えた言語だけを保存した古い内容でも、ほかの言語は既定文になる。
    let json = Data(#"{"boilerplates":{"ja":"書き換えた"}}"#.utf8)
    let settings = try JSONDecoder().decode(Settings.self, from: json)
    #expect(settings.boilerplate(for: .ja) == Boilerplate.japanese)
    #expect(settings.boilerplate(for: .en) == Boilerplate.english)
}

@Test
func customBoilerplateFollowsLanguageUntilEditedAndResetsWhenEmpty() throws {
    var settings = Settings()
    #expect(settings.effectiveBoilerplate == Boilerplate.english)
    settings.language = .ja
    #expect(settings.effectiveBoilerplate == Boilerplate.japanese)
    settings.setBoilerplate(Boilerplate.japanese, for: .ja)
    #expect(settings.customBoilerplate == nil)
    settings.setBoilerplate("共通", for: .ja)
    settings.language = .en
    #expect(settings.effectiveBoilerplate == "共通")
    let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
    #expect(decoded == settings)
    settings.setBoilerplate("", for: .en)
    #expect(settings.customBoilerplate == nil)
    #expect(settings.effectiveBoilerplate == Boilerplate.english)
}

@Test
func legacyBoilerplateMigrationUsesStoredLanguage() throws {
    let custom = Data(#"{"language":"ja","boilerplates":{"en":"ignored","ja":"共通"}}"#.utf8)
    let migrated = try JSONDecoder().decode(Settings.self, from: custom)
    #expect(migrated.customBoilerplate == "共通")
    #expect(migrated.boilerplate(for: .en) == "共通")
    let defaults = try JSONSerialization.data(withJSONObject: ["language": "ja", "boilerplates": Boilerplate.defaults])
    #expect(try JSONDecoder().decode(Settings.self, from: defaults).customBoilerplate == nil)
    let explicitNull = Data(#"{"customBoilerplate":null,"boilerplates":{"en":"old"}}"#.utf8)
    #expect(try JSONDecoder().decode(Settings.self, from: explicitNull).customBoilerplate == nil)
}
