const VAULT = "Manu's vault";
const CUISINE_DIR = 'Cuisine';
const FALLBACK_SUBFOLDERS = ['Cocktails', 'Desserts', 'Plats', 'Recettes de la Nonna', 'Sauces', 'Techniques'];
const URI_LIMIT = 50_000;

// Injected into the page to extract schema.org/Recipe JSON-LD from the DOM.
function extractRecipeFromPage() {
  const fallbackImage =
    document.querySelector('meta[property="og:image"]')?.content ||
    document.querySelector('meta[name="twitter:image"]')?.content ||
    '';

  const scripts = document.querySelectorAll('script[type="application/ld+json"]');
  for (const script of scripts) {
    try {
      const data = JSON.parse(script.textContent);
      const items = data['@graph']
        ? data['@graph']
        : Array.isArray(data) ? data : [data];
      for (const item of items) {
        const t = item['@type'];
        if (t === 'Recipe' || (Array.isArray(t) && t.includes('Recipe'))) {
          if (!item.image && fallbackImage) item.image = fallbackImage;
          return item;
        }
      }
    } catch {}
  }
  return null;
}

function stripHtml(s) {
  return decodeHtmlEntities(s || '').replace(/<[^>]+>/g, '').trim();
}

function decodeHtmlEntities(s) {
  // Use the browser's HTML parser as an entity decoder instead of maintaining
  // our own entity table. A textarea exposes decoded text through .value.
  const textarea = document.createElement('textarea');
  let decoded = s;

  // Some recipe sites double-encode JSON-LD text:
  // "d&amp;eacute;s" -> "d&eacute;s" -> "dés".
  for (let i = 0; i < 3; i += 1) {
    textarea.innerHTML = decoded;
    const next = textarea.value;
    if (next === decoded) break;
    decoded = next;
  }

  return decoded;
}

function safeFilename(s) {
  return s.replace(/[<>:"/\\|?*\n\r\t]/g, '').trim() || 'Recette';
}

function firstImageUrl(image) {
  if (!image) return '';
  if (typeof image === 'string') return image;
  if (Array.isArray(image)) return firstImageUrl(image[0]);
  return image.url || image.contentUrl || '';
}

function buildNote(recipe, url) {
  const name = stripHtml(recipe.name || 'Recette sans nom');
  const imageUrl = firstImageUrl(recipe.image);

  const ingredients = (recipe.recipeIngredient || []).map(stripHtml);

  const instructions = [];
  for (const step of recipe.recipeInstructions || []) {
    if (typeof step === 'string') {
      instructions.push(stripHtml(step));
    } else if (step['@type'] === 'HowToSection') {
      for (const sub of step.itemListElement || []) {
        const t = typeof sub === 'string' ? sub : (sub.text || sub.name || '');
        if (t) instructions.push(stripHtml(t));
      }
    } else {
      const t = step.text || step.name || '';
      if (t) instructions.push(stripHtml(t));
    }
  }

  const lines = [
    '---',
    `source: ${url}`,
    '---',
    '',
    ...(imageUrl ? [`![${name}](${imageUrl})`, ''] : []),
    '### Ingrédients',
    '',
    ...ingredients.map(i => `- ${i}`),
    '',
    '### Préparation',
    '',
    ...instructions.map((s, i) => `${i + 1}. ${s}`),
    '',
  ];

  return { name, content: lines.join('\n') };
}

function setStatus(msg, type = '') {
  const el = document.getElementById('status');
  el.textContent = msg;
  el.className = type;
}

async function getBringDeeplinkWithNativeHost(url) {
  const resp = await sendNativeMessage({ action: 'bringDeeplink', url });
  return resp.deeplink;
}

async function listObsidianFoldersWithNativeHost() {
  const resp = await sendNativeMessage({
    action: 'listObsidianFolders',
    vaultName: VAULT,
    baseDir: CUISINE_DIR,
  });
  return resp.folders;
}

async function sendNativeMessage(message) {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendNativeMessage(
      'com.manu.bringimport',
      message,
      (resp) => {
        if (chrome.runtime.lastError) {
          reject(new Error(`Native host: ${chrome.runtime.lastError.message}`));
          return;
        }
        if (!resp) {
          reject(new Error('Native host: empty response'));
          return;
        }
        if (resp.error) {
          reject(new Error(`Native host: ${resp.error}`));
          return;
        }
        resolve(resp);
      }
    );
  });
}

async function getBringDeeplinkWithFetch(url) {
  const resp = await fetch('https://api.getbring.com/rest/bringrecipes/deeplink', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url, source: 'web' }),
  });

  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(`Direct fetch: HTTP ${resp.status} ${text.slice(0, 160)}`);
  }

  const data = JSON.parse(text);
  if (!data.deeplink) {
    throw new Error('Direct fetch: response did not contain deeplink');
  }
  return data.deeplink;
}

// ── init ──────────────────────────────────────────────────────────────────────

(async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

  const [{ result: recipe }] = await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: extractRecipeFromPage,
  });

  document.getElementById('loading').style.display = 'none';

  if (!recipe) {
    document.getElementById('no-recipe').style.display = 'block';
    return;
  }

  const { name, content } = buildNote(recipe, tab.url);

  document.getElementById('recipe-name').textContent = name;
  document.getElementById('recipe-name').title = name;

  const select = document.getElementById('subfolder');
  let folders = FALLBACK_SUBFOLDERS;
  try {
    const nativeFolders = await listObsidianFoldersWithNativeHost();
    if (Array.isArray(nativeFolders) && nativeFolders.length) {
      folders = nativeFolders;
    }
  } catch (err) {
    console.warn(err);
  }

  for (const folder of folders) {
    const opt = document.createElement('option');
    opt.value = folder;
    opt.textContent = folder;
    select.appendChild(opt);
  }

  document.getElementById('main').style.display = 'block';

  // ── Obsidian ───────────────────────────────────────────────────────────────

  document.getElementById('btn-obsidian').addEventListener('click', () => {
    const subfolder = select.value;
    const filePath = `${CUISINE_DIR}/${subfolder}/${safeFilename(name)}`;
    const uri = `obsidian://new?vault=${encodeURIComponent(VAULT)}&file=${encodeURIComponent(filePath)}&content=${encodeURIComponent(content)}`;

    if (uri.length > URI_LIMIT) {
      setStatus(`Recette trop longue pour l'URI Obsidian (${uri.length.toLocaleString()} caractères, limite : ${URI_LIMIT.toLocaleString()}).`, 'error');
      return;
    }

    chrome.tabs.create({ url: uri });
    setStatus('Note créée dans Obsidian.', 'success');
  });

  // ── Bring! ─────────────────────────────────────────────────────────────────
  // API call is routed through a native Python host so no Origin header is
  // sent — the browser can't make this request directly without getting a 403.

  document.getElementById('btn-bring').addEventListener('click', async () => {
    const btn = document.getElementById('btn-bring');
    btn.disabled = true;
    setStatus('Récupération du lien Bring!…');

    try {
      let deeplink;
      try {
        deeplink = await getBringDeeplinkWithNativeHost(tab.url);
      } catch (nativeErr) {
        console.warn(nativeErr);
        setStatus('Native host indisponible, essai direct…');
        try {
          deeplink = await getBringDeeplinkWithFetch(tab.url);
        } catch (fetchErr) {
          throw new Error(`${nativeErr.message}; ${fetchErr.message}`);
        }
      }

      // window.open from page context triggers the OS bring:// URI handler.
      await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: (url) => window.open(url),
        args: [deeplink],
      });

      setStatus('Ingrédients ajoutés à Bring!', 'success');
    } catch (err) {
      setStatus(`Erreur Bring! : ${err.message}`, 'error');
    } finally {
      btn.disabled = false;
    }
  });
})();
