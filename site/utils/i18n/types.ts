export interface TranslationItem {
    label: string;
    translation: string;
}

export interface LanguageDefinition {
    language: {
        name: string;
        short_form: string;
        language_code: string;
        text_direction: 'ltr' | 'rtl';
        text_editor_lang: string;
    };
    translations: TranslationItem[];
}
