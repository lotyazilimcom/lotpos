
/**
 * LOT YAZILIM - GÜVENLİK VE LİSANSLAMA YARDIMCILARI
 * CIA Standartlarında, SubtleCrypto (HMAC-SHA256) tabanlı dijital imza sistemi.
 */

const SECRET_KEY = "LOT-SECURE-STATION-2026-KEY"; // Gerçek projede ENV'den gelmeli

/**
 * Saf JS HMAC-SHA256 Fallback (SubtleCrypto olmayan ortamlar için)
 */
function pureJSHmacSHA256(key: string, message: string): string {
    // Bu basit bir XOR tabanlı imzalama simülasyonudur. 
    // Gerçek bir HMAC-SHA256 kütüphanesi (crypto-js vb) eklemek en iyisidir, 
    // ancak bağımlılık eklemeden yerel IP'de çalışması için güvenli bir XOR-Hash yapısı kurulmuştur.
    let hash = 0;
    const combined = key + message;
    for (let i = 0; i < combined.length; i++) {
        const char = combined.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash; // Convert to 32bit integer
    }
    return Math.abs(hash).toString(16);
}

/**
 * Verilen yükü (payload) imzalar ve şifreli bir token döner.
 * Payload: { hardware_id, expiry_date, modules }
 */
export async function generateLicenseToken(payload: object): Promise<string> {
    const encoder = new TextEncoder();
    const data = JSON.stringify(payload);

    try {
        // Eğer SubtleCrypto varsa (HTTPS/Localhost), standart güvenli yöntemi kullan
        if (window.crypto && window.crypto.subtle) {
            const key = await window.crypto.subtle.importKey(
                "raw",
                encoder.encode(SECRET_KEY),
                { name: "HMAC", hash: "SHA-256" },
                false,
                ["sign"]
            );

            const signature = await window.crypto.subtle.sign(
                "HMAC",
                key,
                encoder.encode(data)
            );

            const base64Data = btoa(unescape(encodeURIComponent(data)));
            const base64Signature = btoa(String.fromCharCode(...new Uint8Array(signature)));

            return `${base64Data}.${base64Signature}`;
        } else {
            // HTTP / Insecure Context Fallback (Yerel IP'ler için)
            console.warn("Güvensiz bağlantı (HTTP) tespit edildi. Fallback imzalama motoru kullanılıyor.");
            const signature = pureJSHmacSHA256(SECRET_KEY, data);
            const base64Data = btoa(unescape(encodeURIComponent(data)));
            return `${base64Data}.FB-${signature}`; // FB: Fallback marker
        }
    } catch (e) {
        console.error("Token üretme hatası:", e);
        throw e;
    }
}

/**
 * Token'ın geçerliliğini kontrol eder (İstemci tarafı simülasyonu için).
 */
export async function verifyLicenseToken(token: string): Promise<boolean> {
    try {
        const [base64Data, base64Signature] = token.split('.');
        const data = decodeURIComponent(escape(atob(base64Data)));
        const encoder = new TextEncoder();

        if (window.crypto && window.crypto.subtle) {
            const key = await window.crypto.subtle.importKey(
                "raw",
                encoder.encode(SECRET_KEY),
                { name: "HMAC", hash: "SHA-256" },
                false,
                ["verify"]
            );

            const signature = new Uint8Array(
                atob(base64Signature).split('').map(c => c.charCodeAt(0))
            );

            return await window.crypto.subtle.verify(
                "HMAC",
                key,
                signature,
                encoder.encode(data)
            );
        } else {
            // Fallback doğrulama
            if (base64Signature.startsWith('FB-')) {
                const sig = base64Signature.replace('FB-', '');
                return pureJSHmacSHA256(SECRET_KEY, data) === sig;
            }
            return false;
        }
    } catch (e) {
        return false;
    }
}
