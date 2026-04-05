import google.genai as genai
import sys, os

API_KEY = "AIzaSyBt9rNZwiLPzX343JvWKVFGi-MejjZw2Ic"
client = genai.Client(api_key=API_KEY)

articles = [
    {
        "slug": "the-best-vertical-ai-products-start-with-a-complaint-not-a-demo",
        "prompt": (
            "Editorial illustration for an AI business article. "
            "Split composition: left side shows a chaotic desk covered in paper forms, phone, "
            "and sticky notes representing a messy business complaint workflow. "
            "Right side shows a clean, minimal digital interface with one focused green checkmark. "
            "Dark navy background with warm gold accent lines. "
            "Style: editorial infographic with architectural line work. "
            "No text. Cinematic lighting, professional, minimal."
        ),
        "out": "/home/administrator/site/public/images/articles/lc-the-best-vertical-ai-products-start-with-a-complaint-not-a-demo.png"
    },
    {
        "slug": "managed-ai-services-are-the-real-agent-business",
        "prompt": (
            "Editorial illustration for an AI operations article. "
            "A human operator sits at a desk commanding a wall of glowing service dashboards, "
            "each showing different metrics and status indicators. "
            "The dashboards are connected by subtle golden thread lines suggesting orchestration. "
            "Dark navy background. Style: clean editorial tech illustration. "
            "Warm gold and cool blue accents. No text. Minimal, authoritative."
        ),
        "out": "/home/administrator/site/public/images/articles/lc-managed-ai-services-are-the-real-agent-business.png"
    },
    {
        "slug": "the-best-ai-builder-tools-are-starting-to-look-like-control-panels-not-chatbots",
        "prompt": (
            "Editorial illustration for an AI tooling article. "
            "A futuristic control panel with sliders, toggle switches, status LEDs, "
            "and waveform monitors arranged in a grid. "
            "Soft blue and gold indicator lights glow against a deep navy background. "
            "No chatbots or chat bubbles. Style: industrial control panel aesthetic. "
            "Clean vector lines, no text. Professional and precise."
        ),
        "out": "/home/administrator/site/public/images/articles/lc-the-best-ai-builder-tools-are-starting-to-look-like-control-panels-not-chatbots.png"
    },
    {
        "slug": "small-operators-are-building-ai-systems-that-feel-more-like-services-than-software",
        "prompt": (
            "Editorial illustration for a small business AI article. "
            "A solopreneur or small team operator at a standing desk surrounded by three floating "
            "AI service panels showing task cards, calendar blocks, and notification bells. "
            "The panels orbit gently around the operator like a command center. "
            "Dark navy background with warm gold and cool blue accents. "
            "Style: editorial tech illustration. No text. Approachable but professional."
        ),
        "out": "/home/administrator/site/public/images/articles/lc-small-operators-are-building-ai-systems-that-feel-more-like-services-than-software.png"
    },
]

for art in articles:
    out = art["out"]
    print(f"\nGenerating: {art['slug']}")
    try:
        resp = client.models.generate_images(
            model="imagen-4.0-generate-001",
            prompt=art["prompt"],
            config={"aspectRatio": "16:9"}
        )
        for image in resp.generated_images:
            with open(out, "wb") as f:
                f.write(image.image.image_bytes)
            size = os.path.getsize(out)
            print(f"  SAVED: {out} ({size} bytes)")
    except Exception as e:
        print(f"  ERROR: {e}")
        sys.exit(1)

print("\nAll done.")
