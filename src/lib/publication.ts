import type { CollectionEntry } from 'astro:content';
import { getCollection, render } from 'astro:content';
import { AUTHOR_BANK } from './authors';

export type PublicationEntry = CollectionEntry<'publication'>;

export type PublicationPost = {
  slug: string;
  title: string;
  date: string;
  category: string;
  tags: Array<string>;
  excerpt: string;
  author: string;
  authorImage: string;
  authorBio: string;
  type: string;
  image: string;
  sources: Array<string>;
  body?: string;
};

const placeholderPosts: Array<PublicationPost> = [
  {
    slug: 'openclaw-managed-services',
    title: 'The quiet business behind AI agents is managed service work',
    date: 'March 28, 2026',
    category: 'ai-services',
    tags: ['OpenClaw', 'managed-ai', 'services'],
    excerpt:
      'The durable money is not in showing an agent once. It is in installing, monitoring, and maintaining a system someone depends on every week.',
    author: 'Publication Staff',
    authorImage: '',
    authorBio: '',
    type: 'analysis',
    sources: ['https://github.com/openclaw/openclaw'],
    image: '',
    body:
      'The recurring business opportunity around AI agents is not a one-time demo. It is the service layer that keeps a useful workflow alive after setup.\n\nThat means installation, prompt maintenance, routing, monitoring, and enough operational discipline that the customer experiences reliability instead of novelty.\n\nSmall operators do not buy benchmark charts. They buy confidence that a system will keep doing the ugly repetitive work they already hate.',
  },
  {
    slug: 'vertical-ai-pain-point',
    title: 'The best vertical AI products start with a complaint, not a demo',
    date: 'March 27, 2026',
    category: 'pain-points',
    tags: ['vertical-ai', 'small-business', 'operations'],
    excerpt:
      'If nobody is publicly complaining about the workflow, you probably have not found the right niche pain point yet.',
    author: 'Publication Staff',
    authorImage: '',
    authorBio: '',
    type: 'niche-teardown',
    sources: ['https://news.ycombinator.com/'],
    image: '',
    body:
      'The useful question is not what a model can do in theory. It is what a business owner is already frustrated enough to describe in public.\n\nOnce the complaint is concrete, the workflow becomes more legible. That is where an automation product starts earning the right to exist.',
  },
  {
    slug: 'tooling-stack-for-publications',
    title: 'A practical content stack for shipping an AI publication without a newsroom',
    date: 'March 26, 2026',
    category: 'tooling-dx',
    tags: ['astro', 'content-ops', 'publishing'],
    excerpt:
      'A small publication does not need a giant CMS. It needs reliable markdown, a review loop, and enough discipline to keep the pipeline clean.',
    author: 'Publication Staff',
    authorImage: '',
    authorBio: '',
    type: 'tutorials-patterns',
    sources: ['https://astro.build/'],
    image: '',
    body:
      'A lean publishing stack wins by reducing moving parts. Markdown with frontmatter, a clear review loop, and a stable rendering layer will beat a bloated workflow almost every time.\n\nThe complexity should live in editorial judgment, not in ten different systems pretending to help.',
  },
  {
    slug: 'builder-spotlight',
    title: 'Small operators are building AI systems that feel more like services than software',
    date: 'March 25, 2026',
    category: 'builder-spotlight',
    tags: ['builders', 'ops', 'spotlight'],
    excerpt:
      'The interesting pattern is not a flashy launch. It is small teams quietly wrapping automation with configuration, support, and accountability.',
    author: 'Publication Staff',
    authorImage: '',
    authorBio: '',
    type: 'profile',
    sources: ['https://hnrss.org/show'],
    image: '',
    body:
      'The strongest builder stories right now do not look like giant product launches. They look like operators building systems that keep a client workflow moving without drama.\n\nThat is closer to managed infrastructure than app theater, and that is exactly why it matters.',
  },
  {
    slug: 'release-watch',
    title: 'Release notes are starting to matter more than launch events',
    date: 'March 24, 2026',
    category: 'releases-changelog',
    tags: ['releases', 'changelog', 'models'],
    excerpt:
      'For builders, the real signal lives in pricing changes, context shifts, API details, and what quietly got deprecated.',
    author: 'Publication Staff',
    authorImage: '',
    authorBio: '',
    type: 'breaking',
    sources: ['https://github.com/openclaw/openclaw/releases.atom'],
    image: '',
    body:
      'The launch event gets attention. The changelog changes actual work.\n\nIf you are building on top of these systems, the details hiding in release notes matter more than the keynote energy does.',
  },
  {
    slug: 'openclaw-ecosystem',
    title: 'The OpenClaw ecosystem is becoming a real operating surface, not just a local toy',
    date: 'March 23, 2026',
    category: 'openclaw-ecosystem',
    tags: ['OpenClaw', 'agents', 'workflow'],
    excerpt:
      'The interesting story is not raw autonomy. It is whether the system can support durable workflows, approvals, and useful handoffs.',
    author: 'Publication Staff',
    authorImage: '',
    authorBio: '',
    type: 'opinion',
    sources: ['https://github.com/openclaw/openclaw'],
    image: '',
    body:
      'A local agent system becomes serious when it stops being a novelty and starts supporting work that survives handoffs, interruptions, and approvals.\n\nThat is where ecosystem questions become operational questions, and where architecture suddenly matters a lot more than demos.',
  },
];

const homepageFeaturedOrder: Array<string> = [
  'local-first-agent-systems-stop-being-toys-when-they-can-survive-handoffs',
  'the-best-ai-builder-tools-are-starting-to-look-like-control-panels-not-chatbots',
  'the-best-vertical-ai-products-start-with-a-complaint-not-a-demo',
  'release-notes-are-starting-to-matter-more-than-launch-events',
  'the-next-wave-of-ai-service-businesses-will-look-more-like-operators-than-agencies',
];

const defaultAuthorAliases = new Set(['', 'Publication Staff']);

const fallbackArticleImagePool: Array<string> = [
  '/images/articles/art1-robotic-relay.jpg',
  '/images/articles/art2-operations-center.jpg',
  '/images/articles/art3-control-panel.jpg',
  '/images/articles/art4-changelog.jpg',
  '/images/articles/art5-service-tech.jpg',
  '/images/articles/art6-dev-dashboard.jpg',
  '/images/articles/art7-amber-server.jpg',
];

function slugHash(slug: string): number {
  return Array.from(slug).reduce((acc, ch) => acc + ch.charCodeAt(0), 0);
}

function resolveAuthorProfileBySlug(slug: string) {
  const index = slugHash(slug) % AUTHOR_BANK.length;
  return AUTHOR_BANK[index];
}

function resolveAuthorProfileByName(name: string) {
  const clean = name.trim().toLowerCase();
  return AUTHOR_BANK.find((p) => p.name.toLowerCase() === clean);
}

function resolveAuthorName(slug: string, author?: string): string {
  if (author && !defaultAuthorAliases.has(author.trim())) {
    return author;
  }

  return resolveAuthorProfileBySlug(slug).name;
}

function resolveAuthorImage(slug: string, author?: string, authorImage = ''): string {
  if (authorImage.trim()) {
    return authorImage;
  }

  if (author && !defaultAuthorAliases.has(author.trim())) {
    const matched = resolveAuthorProfileByName(author);
    return matched?.imagePath ?? '';
  }

  return resolveAuthorProfileBySlug(slug).imagePath;
}

function resolveAuthorBio(slug: string, author?: string, authorBio = ''): string {
  if (authorBio.trim()) {
    return authorBio;
  }

  if (author && !defaultAuthorAliases.has(author.trim())) {
    const matched = resolveAuthorProfileByName(author);
    return matched?.bio ?? 'Signal & Circuit contributor covering practical AI systems and operator workflows.';
  }

  return resolveAuthorProfileBySlug(slug).bio;
}

function resolveArticleImage(slug: string, image?: string): string {
  if (image && image.trim().length > 0) {
    return image;
  }

  const index = slugHash(slug) % fallbackArticleImagePool.length;
  return fallbackArticleImagePool[index];
}

function normalizePost(post: PublicationPost): PublicationPost {
  return {
    ...post,
    author: resolveAuthorName(post.slug, post.author),
    authorImage: resolveAuthorImage(post.slug, post.author, post.authorImage),
    authorBio: resolveAuthorBio(post.slug, post.author, post.authorBio),
    image: resolveArticleImage(post.slug, post.image),
  };
}

function orderPostsBySlug(posts: Array<PublicationPost>, preferredOrder: Array<string>): Array<PublicationPost> {
  const rank = new Map(preferredOrder.map((slug, index) => [slug, index]));

  return [...posts].sort((a, b) => {
    const aRank = rank.get(a.slug);
    const bRank = rank.get(b.slug);

    if (aRank != null && bRank != null) {
      return aRank - bRank;
    }

    if (aRank != null) {
      return -1;
    }

    if (bRank != null) {
      return 1;
    }

    return 0;
  });
}

export async function getPublicationPosts(): Promise<Array<PublicationPost>> {
  const livePosts = (await getCollection('publication', ({ data }) => !data.draft)).sort(
    (a, b) => b.data.date.valueOf() - a.data.date.valueOf(),
  );

  if (livePosts.length === 0) {
    return placeholderPosts.map(normalizePost);
  }

  const rendered = await Promise.all(
    livePosts.map(async (post) => {
      const { Content } = await render(post);
      void Content;
      return normalizePost({
        slug: post.id,
        title: post.data.title,
        date: post.data.date.toLocaleDateString('en-US', {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
        }),
        category: post.data.category,
        tags: post.data.tags,
        excerpt: post.data.excerpt,
        author: post.data.author,
        authorImage: post.data.authorImage,
        authorBio: post.data.authorBio,
        type: post.data.type,
        image: post.data.image ?? '',
        sources: post.data.sources,
        body: post.body,
      } satisfies PublicationPost);
    }),
  );

  return rendered;
}

export async function getHomepagePublicationPosts(): Promise<Array<PublicationPost>> {
  const posts = await getPublicationPosts();
  return orderPostsBySlug(posts, homepageFeaturedOrder);
}

export async function getPublicationPost(slug: string): Promise<PublicationPost | undefined> {
  const posts = await getPublicationPosts();
  return posts.find((post) => post.slug === slug);
}

export async function getPublicationCategories(): Promise<Array<string>> {
  const posts = await getPublicationPosts();
  return Array.from(new Set(posts.map((post) => post.category))).sort();
}

export async function getPublicationTags(): Promise<Array<string>> {
  const posts = await getPublicationPosts();
  return Array.from(new Set(posts.flatMap((post) => post.tags))).sort();
}
