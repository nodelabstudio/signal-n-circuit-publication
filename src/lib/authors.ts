export type AuthorProfile = {
  name: string;
  slug: string;
  imagePath: string;
  bio: string;
  portraitPrompt: string;
};

export const AUTHOR_BANK: Array<AuthorProfile> = [
  {
    name: 'Nora Vale',
    slug: 'nora-vale',
    imagePath: '/images/authors/nora-vale.jpg',
    bio: 'Nora covers AI service operations, delivery playbooks, and what makes automation survive real client handoffs.',
    portraitPrompt:
      'Editorial portrait of Nora Vale, early-30s Latina woman, short dark wavy hair, warm neutral blazer over black top, confident and approachable expression, chest-up framing, soft studio key light with gentle rim light, cinematic depth of field, realistic skin texture, subtle newsroom backdrop with muted warm-gray tones, high-detail photoreal style, no text, no watermark, no logos.',
  },
  {
    name: 'Eli Mercer',
    slug: 'eli-mercer',
    imagePath: '/images/authors/eli-mercer.jpg',
    bio: 'Eli reports on model releases, API shifts, and product decisions that materially change builder workflows.',
    portraitPrompt:
      'Editorial portrait of Eli Mercer, mid-30s white male, light stubble, short brown hair, charcoal button-down shirt, analytical expression with slight half-smile, chest-up framing, moody but clean magazine lighting, out-of-focus desk and monitor glow in background, neutral palette, photorealistic, no text, no watermark, no logos.',
  },
  {
    name: 'Sana Brooks',
    slug: 'sana-brooks',
    imagePath: '/images/authors/sana-brooks.jpg',
    bio: 'Sana focuses on niche operator pain points and translates messy field problems into viable product opportunities.',
    portraitPrompt:
      'Editorial portrait of Sana Brooks, late-20s Black woman, natural curls tied back, olive jacket over cream shirt, poised direct gaze, chest-up framing, soft diffused light, modern newsroom ambiance with shallow depth of field, understated color grade, highly realistic portrait photography style, no text, no watermark, no logos.',
  },
  {
    name: 'Rowan Pike',
    slug: 'rowan-pike',
    imagePath: '/images/authors/rowan-pike.jpg',
    bio: 'Rowan writes analysis on AI business models, pricing pressure, and where recurring value is actually being captured.',
    portraitPrompt:
      'Editorial portrait of Rowan Pike, early-40s white male, salt-and-pepper hair, rectangular glasses, navy blazer and dark tee, thoughtful expression, chest-up framing, directional key light from left, subtle publication office background blur, realistic tonal contrast and skin detail, no text, no watermark, no logos.',
  },
  {
    name: 'Iris Calder',
    slug: 'iris-calder',
    imagePath: '/images/authors/iris-calder.jpg',
    bio: 'Iris covers developer tooling and evaluates whether new AI interfaces reduce friction or just move it around.',
    portraitPrompt:
      'Editorial portrait of Iris Calder, mid-30s East Asian woman, sleek shoulder-length black hair, dark green blouse, focused calm expression, chest-up framing, clean cinematic portrait lighting, warm-neutral editorial color palette, softly blurred newsroom shelves in background, photorealistic, no text, no watermark, no logos.',
  },
  {
    name: 'Micah Sloan',
    slug: 'micah-sloan',
    imagePath: '/images/authors/micah-sloan.jpg',
    bio: 'Micah tracks implementation reliability, monitoring patterns, and what breaks first when agent systems hit production.',
    portraitPrompt:
      'Editorial portrait of Micah Sloan, early-30s Black male, close-cropped hair and trimmed beard, dark bomber jacket over gray shirt, relaxed confident posture, chest-up framing, balanced softbox lighting, muted industrial newsroom backdrop, realistic high-detail portrait, no text, no watermark, no logos.',
  },
  {
    name: 'Leah Kade',
    slug: 'leah-kade',
    imagePath: '/images/authors/leah-kade.jpg',
    bio: 'Leah writes practitioner-first explainers on agent architecture, approvals, and local-first operational design.',
    portraitPrompt:
      'Editorial portrait of Leah Kade, late-20s Middle Eastern woman, long dark hair tucked behind one ear, minimalist beige blazer, observant expression, chest-up framing, soft editorial lighting with subtle vignette, calm blurred office background, photoreal, no text, no watermark, no logos.',
  },
  {
    name: 'Jonah Keene',
    slug: 'jonah-keene',
    imagePath: '/images/authors/jonah-keene.jpg',
    bio: 'Jonah reports on builder launches, positioning strategy, and how small teams turn technical leverage into distribution.',
    portraitPrompt:
      'Editorial portrait of Jonah Keene, late-30s white male, curly dark hair, no beard, black crewneck sweater, direct candid expression, chest-up framing, refined magazine portrait light, warm-gray backdrop with slight texture, realistic detail and natural skin, no text, no watermark, no logos.',
  },
  {
    name: 'Priya Noland',
    slug: 'priya-noland',
    imagePath: '/images/authors/priya-noland.jpg',
    bio: 'Priya covers cross-functional AI operations, from editorial systems to marketing workflows and execution quality.',
    portraitPrompt:
      'Editorial portrait of Priya Noland, early-30s South Asian woman, medium-length dark hair, navy blouse, calm assertive expression, chest-up framing, soft key light and subtle fill, modern editorial newsroom bokeh background, realistic portrait photography look, no text, no watermark, no logos.',
  },
  {
    name: 'Gabe Holloway',
    slug: 'gabe-holloway',
    imagePath: '/images/authors/gabe-holloway.jpg',
    bio: 'Gabe analyzes market structure and competitive dynamics in the AI tooling ecosystem with an operator lens.',
    portraitPrompt:
      'Editorial portrait of Gabe Holloway, early-40s Latino male, cropped dark hair with slight gray at temples, dark overshirt, composed serious expression, chest-up framing, cinematic soft light with controlled shadows, blurred publication desk backdrop, photorealistic, no text, no watermark, no logos.',
  },
];
