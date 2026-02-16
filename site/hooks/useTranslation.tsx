import { useLanguage } from '../context/LanguageContext';

export const useTranslation = () => {
    const { t, setLanguage, loading, currentLang, dir } = useLanguage();
    return { t, setLanguage, loading, currentLang, dir };
};
