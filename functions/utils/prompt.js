function buildPrompt({
  title,
  category,
  ingredients,
  steps = [],
  strict = false,
}) {
  /* ── 1. Normalisation des entrées ─────────────────────────── */
  const safeTitle = String(title || "").trim().replace(/\s+/g, " ").slice(0, 80);

  const normalizeCategory = (c) => {
    const s = String(c || "").trim().toLowerCase()
      .normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    if (s === "entree") return "entrée";
    if (s === "plat") return "plat";
    if (s === "dessert") return "dessert";
    if (s === "boisson") return "boisson";
    return "plat";
  };

  const cat = normalizeCategory(category);
  const lowerTitle = safeTitle.toLowerCase();
  const prepText = Array.isArray(steps) ? steps.join(" ").toLowerCase() : "";

  const normalizeIngredient = (s) => {
    let t = String(s || "").trim().toLowerCase();
    t = t.replace(/\b\d+([.,]\d+)?\b/g, " ");
    t = t.replace(/\b(x|×)\s*\d+\b/g, " ");
    t = t.replace(/\b(kg|g|gr|mg|ml|cl|dl|l|litre|litres|cuil\.|cuill\.|cuillère|cuillerées?|soupe|café|cas|càs|cac|càc|cc|cs)\b/g, " ");
    t = t.replace(/[()[\]]/g, " ");
    t = t.replace(/https?:\/\/\S+|www\.\S+|[@€#]/g, " ");
    t = t.replace(/\s+/g, " ").trim();
    return t;
  };

  const STOP = new Set([
    "sel", "poivre", "eau", "huile", "huile olive", "huile d'olive",
    "huile végétale", "huile de tournesol", "huile de colza",
    "vinaigre", "vinaigre balsamique", "sucre", "sucre glace",
    "farine", "maïzena", "fécule", "levure", "beurre clarifié",
    "épices", "herbes", "assaisonnement", "muscade", "cannelle",
  ]);

  const ingAll = (Array.isArray(ingredients) ? ingredients : [])
    .map(normalizeIngredient)
    .filter(Boolean)
    .filter((x) => x.length > 1 && !STOP.has(x));

  const ingText = ingAll.join(" ");
  const fullText = `${lowerTitle} ${ingText} ${prepText}`;
  const fullTextNoAccent = fullText.normalize("NFD").replace(/[\u0300-\u036f]/g, "");

  /* ── 2. Détections sémantiques ────────────────────────────── */
  const has = (re) => re.test(fullText) || re.test(fullTextNoAccent);

  // Formats de plat
  const isSoupLike    = has(/\b(soupe|potage|velout[eé]|velouté|bouillon|consommé|minestrone|ramen|pho|gaspacho|gazpacho|vichyssoise|bisque|bouillabaisse|garbure)\b/);
  const isSaladLike   = has(/\b(salade|taboul[eé])\b/);
  const isSkewerLike  = has(/\b(brochette|kebab|skewer|yakitori|satay|spiedino)\b/);
  const isStewLike    = has(/\b(curry|tajine|rago[uû]t|daube|stew|ragout|blanquette|fricassée|fricassee|navarin|pot.au.feu|pot au feu|bourguignon|cassoulet|goulash)\b/);
  const isGratinLike  = has(/\b(gratin|lasagne|lasagnes|moussaka|parmentier)\b/);
  const isPizzaLike   = has(/\b(pizza|pizzas|tarte flambée|flammekueche)\b/);
  const isBurgerLike  = has(/\b(burger|hamburger|cheeseburger|smash)\b/);
  const isTacoLike    = has(/\b(taco|tacos|wrap|burrito|quesadilla|fajita)\b/);
  const isSushiLike   = has(/\b(sushi|sashimi|maki|temaki|chirashi|poke bowl|poké)\b/);
  const isWokLike     = has(/\b(wok|sauté|pad thai|nasi goreng|fried rice|chop suey)\b/);
  const isNoodleDish  = has(/\b(pad thai|nouilles|vermicelles|rice noodle|udon|soba|ramen)\b/) && !isSoupLike;
  const isPastaLike   = has(/\b(pâtes|pates|spaghetti|penne|tagliatelle|linguine|fettuccine|rigatoni|fusilli|farfalle|carbonara|bolognaise|bolognese|amatriciana|arrabiata|cacio e pepe)\b/) ||
                        (has(/\bpâte\b/) && has(/\b(fraîche|sèche|blé|italienne)\b/)) ||
                        isNoodleDish;
  const isRisottoLike = has(/\b(risotto|riz sauté|riz pilaf|paella|arancini)\b/);
  const isCrepeLike   = has(/\b(crêpe|crepe|galette|pancake|blini)\b/);
  const isOmeletLike  = has(/\b(omelette|omelette|frittata|tortilla española)\b/);
  const isQuicheLike  = has(/\b(quiche|tarte sal[eé]e|flamiche|pissaladière)\b/);
  const isCakeLike    = has(/\b(gâteau|cake|brownie|muffin|cupcake|cheesecake|tarte|clafoutis|fondant|moelleux|charlotte|tiramisu|panna cotta|île flottante)\b/);
  const isBowlLike    = has(/\b(bowl|buddha bowl|açaï bowl)\b/);
  const isSpringRoll  = has(/\b(nem|nems|spring roll|rouleau de printemps)\b/);
  const isDumplingLike = has(/\b(ravioli|raviolis|dim sum|gyoza|dumpling|wontons?|pierogi)\b/);

  // Ingrédients cardinaux
  const hasRice       = has(/\b(riz|risotto|paella)\b/) || isRisottoLike;
  const hasPasta      = isPastaLike;
  const hasPotato     = has(/\b(pomme de terre|pommes de terre|patate|patates|frites|gnocchi)\b/);
  const hasBread      = has(/\b(pain|baguette|bun|buns|brioche|toast|crouton)\b/) || isBurgerLike;
  const hasWrap       = has(/\b(wrap|tortilla|pita|naan|chapati)\b/) || isTacoLike;
  const hasLentils    = has(/\b(lentille|lentilles)\b/);
  const hasCoconut    = has(/\b(coco|lait de coco|crème de coco)\b/);
  const hasCheese     = has(/\b(fromage|gruyère|parmesan|mozzarella|emmental|comté|cheddar|feta|roquefort|camembert|brie|chèvre|ricotta|mascarpone)\b/);
  const hasEgg        = has(/\b(oeuf|oeufs|œuf|œufs)\b/);
  const hasChocolate  = has(/\b(chocolat|cacao)\b/);
  const hasCouscous   = has(/\b(couscous|semoule)\b/);
  const hasQuinoa     = has(/\b(quinoa)\b/);

  // Cuisines du monde
  const isCreoleLike  = has(/\b(rougail|colombo|cari|carry|massalé|boucané|rougaille|vindaye)\b/);
  const isAsianLike   = has(/\b(miso|dashi|teriyaki|tempura|kimchi|bibimbap|laksa|tom yum|rendang|nasi|satay)\b/) || isSushiLike || isWokLike;
  const isNorthAfrican = has(/\b(tajine|couscous|harissa|chermoula|ras el hanout|merguez)\b/) || hasCouscous;
  const isIndianLike  = has(/\b(masala|tikka|korma|vindaloo|biryani|dal|dahl|samosa|chutney|tandoori)\b/) || (hasLentils && has(/\b(cumin|coriandre|curcuma|curry|garam)\b/));
  const isItalianLike = isPastaLike || isRisottoLike || isPizzaLike || isDumplingLike;
  const isMexicanLike = isTacoLike || has(/\b(guacamole|salsa|enchilada|nachos|chili con carne)\b/);

  // Texture / mode de cuisson spécial
  const isFried       = has(/\b(frit|frite|friture|tempura|beignet)\b/);
  const isGrilled     = has(/\b(grillé|grillée|grillés|plancha|barbecue|bbq)\b/);
  const isSteamed     = has(/\b(vapeur|cuit à la vapeur)\b/);

  /* ── 3. Contexte de service (vessel) ─────────────────────── */
  const isBowlDish = isSoupLike || isStewLike || isBowlLike || isRisottoLike ||
    (hasLentils && (hasCoconut || isIndianLike)) || isWokLike;

  const dishVessel = (() => {
    if (cat === "boisson")   return "in a glass";
    if (isSushiLike)         return "on a wooden board";
    if (isBurgerLike)        return "on a wooden board";
    if (isSkewerLike)        return "on a plate";
    if (isPizzaLike)         return "on a wooden board";
    if (isBowlLike || isSushiLike && has(/\bpoke\b/)) return "in a bowl";
    if (isBowlDish)          return "in a bowl";
    if (isSaladLike)         return "in a salad bowl";
    if (isTacoLike)          return "on a plate";
    if (isCrepeLike)         return "on a plate";
    return "on a ceramic plate";
  })();

  /* ── 4. Ingrédients clés pour le prompt visuel ───────────── */
  const pickFirst = (list) => {
    for (const c of list) {
      const re = new RegExp(`\\b${c}\\b`, "i");
      const found = ingAll.find((x) => re.test(x));
      if (found) return found;
    }
    return "";
  };

  const chosen = [];

  if (cat === "boisson") {
    const v = pickFirst(["citron", "orange", "fraise", "mangue", "banane", "coco", "menthe", "grenadine", "pastèque", "ananas", "pêche", "framboise"]);
    if (v) chosen.push(v);

  } else if (cat === "dessert") {
    if (hasChocolate) chosen.push("chocolat");
    const v = pickFirst(["pomme", "poire", "fraise", "framboise", "citron", "vanille", "caramel", "noix", "amande", "noisette", "abricot", "cerise", "mangue"]);
    if (v && !chosen.includes(v)) chosen.push(v);

  } else {
    // Base glucidique
    if (isPastaLike)   chosen.push(pickFirst(["spaghetti", "pâtes", "penne", "tagliatelle", "linguine", "fettuccine", "rigatoni", "fusilli"]) || "pâtes");
    else if (isRisottoLike) chosen.push("riz");
    else if (isNorthAfrican && hasCouscous) chosen.push("couscous");
    else if (hasRice && !isPastaLike) chosen.push("riz");
    else if (hasPotato) chosen.push(pickFirst(["pomme de terre", "pommes de terre", "patate", "gnocchi"]) || "pommes de terre");
    else if (hasQuinoa) chosen.push("quinoa");

    // Protéine principale
    const protein = pickFirst([
      "poulet", "dinde", "canard", "lapin",
      "boeuf", "bœuf", "veau", "porc", "agneau", "mouton",
      "saumon", "thon", "cabillaud", "lieu", "truite", "dorade", "bar", "poisson",
      "crevette", "crevettes", "gambas", "homard", "langoustine", "moule", "moules", "coquille saint-jacques",
      "saucisse", "saucisses", "merguez", "chipolata", "lardons", "jambon", "chorizo", "andouille",
      "oeuf", "oeufs", "œuf", "œufs",
      "tofu", "tempeh", "seitan",
    ]);
    if (protein && !chosen.includes(protein)) chosen.push(protein);

    // Légumes/fruits caractéristiques
    const vegs = [
      "tomate", "tomates", "aubergine", "courgette", "poivron", "poivrons",
      "champignon", "champignons", "épinard", "épinards", "brocoli",
      "carotte", "carottes", "navet", "navets", "céleri", "fenouil",
      "concombre", "avocat", "artichaut", "asperge", "asperges",
      "oignon", "échalote", "poireau", "ail",
      "chou", "chou-fleur", "bette", "blette",
      "petits pois", "haricot", "haricots verts",
      "potiron", "potimarron", "butternut", "courge",
      "betterave", "radis", "endive",
      "coriandre", "menthe", "basilic", "persil", "ciboulette",
      "citron", "lime", "orange", "pomme",
      "lentille", "lentilles", "pois chiche", "pois chiches", "flageolet",
    ];
    for (const v of vegs) {
      if (chosen.length >= 4) break;
      const re = new RegExp(`\\b${v}\\b`, "i");
      const found = ingAll.find((x) => re.test(x));
      if (found && !chosen.includes(found)) chosen.push(found);
    }
  }

  // Cas spéciaux : forcer un ingrédient implicite
  if (isCreoleLike && !chosen.includes("riz")) chosen.push("riz");
  if (isNorthAfrican && hasCouscous && !chosen.includes("couscous")) chosen.unshift("couscous");
  if (isIndianLike && hasLentils && !chosen.some(x => /lentille/.test(x))) chosen.unshift("lentilles");

  const keyIngredients = chosen.slice(0, 4);

  /* ── 5. Règles d'interdiction (forbid) ───────────────────── */
  const forbid = [];

  // Pasta
  if (!hasPasta && !isDumplingLike) {
    forbid.push(" NO pasta, NO noodles, NO spaghetti, NO penne, NO ramen, NO udon, NO rice noodles of any kind.");
  }
  // Rice
  if (!hasRice && !isCreoleLike && !isIndianLike && !isAsianLike && !isNorthAfrican && !isRisottoLike) {
    forbid.push(" NO rice, NO risotto, NO rice grains of any kind.");
  }
  // Potatoes
  if (!hasPotato && !isBurgerLike) {
    forbid.push(" NO fries, NO potatoes, NO gnocchi.");
  }
  // Bread / buns
  if (!hasBread && !isBurgerLike) {
    forbid.push(" NO burger buns, NO bread slices, NO baguette.");
  }
  // Wraps/tacos
  if (!hasWrap && !isTacoLike) {
    forbid.push(" NO tortillas, NO wraps, NO pita.");
  }
  // Pizza
  if (!isPizzaLike) {
    forbid.push(" NO pizza, NO pizza crust.");
  }
  // Burger
  if (!isBurgerLike) {
    forbid.push("NO burger, NO hamburger.");
  }
  // Sushi
  if (!isSushiLike) {
    forbid.push("NO sushi, NO maki, NO sashimi.");
  }
  // Crêpes
  if (!isCrepeLike) {
    forbid.push("NO crêpes, NO pancakes.");
  }

  /* ── 6. Règles de forme (shapeRules) ─────────────────────── */
  const shapeRules = [];

  if (isSoupLike) {
    shapeRules.push(" SOUP/VELOUTÉ: liquid or creamy broth clearly visible in a bowl or deep plate, steam optional.");
  }
  if (isSaladLike && !isSoupLike) {
    shapeRules.push(" SALAD: raw or cooked vegetables clearly visible, served in a salad bowl or on a flat plate. No hot sauce poured over.");
    if (!hasPasta) shapeRules.push("No noodles in this salad.");
  }
  if (isSkewerLike) {
    shapeRules.push(" SKEWERS: meat/vegetable pieces visibly threaded on wooden or metal sticks.");
  }
  if (isStewLike && !isSoupLike) {
    shapeRules.push(" STEW/BRAISE: thick sauce coating the ingredients, served in a deep plate or bowl.");
  }
  if (isGratinLike) {
    shapeRules.push(" GRATIN: golden-brown melted cheese crust on top, baked dish in a gratin dish or on a plate.");
  }
  if (isPizzaLike) {
    shapeRules.push(" PIZZA: round flat dough with visible toppings, slight char on crust.");
  }
  if (isBurgerLike) {
    shapeRules.push(" BURGER: stacked bun with visible patty, lettuce, tomato, cheese layers.");
  }
  if (isTacoLike) {
    shapeRules.push(" TACO/WRAP: folded or rolled tortilla with visible filling.");
  }
  if (isSushiLike) {
    shapeRules.push(" SUSHI/POKE: carefully arranged pieces on a board or in a bowl, Japanese aesthetic.");
  }
  if (isWokLike && !isSoupLike) {
    shapeRules.push(" WOK DISH: stir-fried ingredients with glossy sauce, served in a bowl or on a plate.");
  }
  if (isNoodleDish && !isPastaLike) {
    shapeRules.push(" NOODLE DISH: stir-fried noodles clearly visible, toppings arranged on top.");
  }
  if (isPastaLike) {
    const pastaType = pickFirst(["spaghetti", "penne", "tagliatelle", "linguine", "fettuccine", "rigatoni", "fusilli"]) || "pasta";
    shapeRules.push(` PASTA DISH: ${pastaType} clearly visible as the main component, sauce coating the pasta.`);
  }
  if (isRisottoLike && !isPastaLike) {
    shapeRules.push(" RISOTTO/RICE DISH: creamy rice visible, served in a deep plate or bowl.");
  }
  if (isNorthAfrican) {
    shapeRules.push(" NORTH AFRICAN DISH: couscous grains or tagine visible, served in traditional earthenware or on a plate.");
  }
  if (isCreoleLike) {
    shapeRules.push(" CREOLE DISH: white rice mound on the side, rich tomato-based sauce with visible meat or sausages on the other side of the plate.");
  }
  if (isIndianLike) {
    shapeRules.push(" INDIAN-INSPIRED DISH: thick spiced sauce, served in a bowl or on a plate with rice or naan.");
  }
  if (isCrepeLike) {
    shapeRules.push(" CRÊPE/PANCAKE: thin folded or stacked pancakes, golden edges visible.");
  }
  if (isQuicheLike) {
    shapeRules.push(" QUICHE/TART: shortcrust pastry shell visible with creamy filling, slice on a plate.");
  }
  if (isOmeletLike) {
    shapeRules.push(" OMELETTE/FRITTATA: folded or flat egg dish with visible filling, golden exterior.");
  }
  if (isCakeLike && cat === "dessert") {
    shapeRules.push(" DESSERT: plated slice or portion, elegant presentation, garnish if relevant.");
  }
  if (isSpringRoll) {
    shapeRules.push(" SPRING ROLLS/NEMS: crispy golden rolls on a plate, dipping sauce optional.");
  }
  if (isDumplingLike) {
    shapeRules.push(" DUMPLINGS/RAVIOLI: plump filled pasta pieces, sauce or broth visible.");
  }
  if (isBowlLike && !isSoupLike && !isWokLike) {
    shapeRules.push(" BOWL: arranged sections of ingredients visible from above or 3/4 angle.");
  }
  if (isFried && !isBurgerLike) {
    shapeRules.push(" FRIED DISH: crispy golden exterior, slight oil sheen.");
  }
  if (isGrilled) {
    shapeRules.push(" GRILLED: visible grill marks on the protein or vegetables.");
  }

  /* ── 7. Assemblage du prompt final ───────────────────────── */
  const titleLooksWeird =
    safeTitle.length < 3 ||
    /[^a-zA-ZÀ-ÿ0-9''\-\s()]/.test(safeTitle) ||
    (safeTitle.match(/[A-Z]/g)?.length || 0) > safeTitle.length * 0.75;

  const dishName = titleLooksWeird ? "" : `Dish name: "${safeTitle}".`;

  const base = [
    // Interdictions en tête pour forcer le modèle
    forbid.length ? "CRITICAL RESTRICTIONS (violations = rejection):" : "",
    ...forbid,
    "",
    // Règles positives de forme
    shapeRules.length ? "DISH SHAPE RULES:" : "",
    ...shapeRules.map((s) => `→ ${s}`),
    "",
    // Core prompt
    "Photorealistic food photography. A real, edible, appetizing dish.",
    dishName,
    cat ? `Category: ${cat}.` : "",
    keyIngredients.length
      ? `Key visible ingredients (show only what's listed, invent nothing): ${keyIngredients.join(", ")}.`
      : "Do not invent any ingredients.",
    `Single main dish, centered, served ${dishVessel}, on a neutral tabletop.`,
    "Camera angle: three-quarter view (~45°), shallow depth of field, DSLR quality.",
    "Lighting: soft natural daylight, subtle shadows, true-to-life colors, appetizing textures.",
    "Background: simple neutral surface, 1-2 minimal props max (fork, napkin).",
    // Hard constraints toujours présents
    "ABSOLUTE: NO text, NO letters, NO words, NO labels, NO watermarks, NO logos, NO UI.",
    "ABSOLUTE: NO people, NO hands, NO faces, NO animals, NO cartoon elements.",
    "ABSOLUTE: Photograph ONLY the food. Nothing else.",
  ].filter(Boolean);

  if (strict) {
    base.push(
      "Food-only packshot: dish and neutral tabletop ONLY.",
      "No scenery, no nature, no architecture, no fashion, no packaging.",
    );
  }

  const finalPrompt = base.join(" ");

  // Debug logs
  console.log("  Title:", safeTitle, "| Category:", cat);
  console.log(" Detections:", {
    soup: isSoupLike, salad: isSaladLike, pasta: isPastaLike,
    rice: hasRice, stew: isStewLike, pizza: isPizzaLike,
    burger: isBurgerLike, creole: isCreoleLike, asian: isAsianLike,
    northAfrican: isNorthAfrican, indian: isIndianLike,
  });
  console.log(" Key ingredients:", keyIngredients);
  console.log(" Forbid rules:", forbid.length, "| Shape rules:", shapeRules.length);

  return finalPrompt;
}

/* ---------------------- Imagen Image Generation ---------------------- */

async function generateImageBase64(promptText) {
  const ai = getGemini(); // Vertex AI, us-central1, pour Imagen 3

  const result = await withRetry(() =>
    ai.models.generateImages({
      model: "imagen-3.0-generate-002",
      prompt: promptText,
      config: {
        numberOfImages: 1,
        aspectRatio: "1:1",
        outputMimeType: "image/jpeg",
      },
    }),
  );

  const img = result.generatedImages?.[0]?.image?.imageBytes;
  if (!img) throw new Error("No image returned by Imagen");

  return img; // déjà en base64
}

module.exports = {
  buildPrompt,
  generateImageBase64,
};
