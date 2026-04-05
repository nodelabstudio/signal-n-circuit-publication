import google.genai as genai
from PIL import Image
import os

API_KEY = "AIzaSyBt9rNZwiLPzX343JvWKVFGi-MejjZw2Ic"
client = genai.Client(api_key=API_KEY)

images = [
    {
        "slug": "local-first-agent-systems-handoffs",
        "prompt": (
            "Editorial illustration for an AI agents article. "
            "A smartphone on the left passes a glowing data token to a laptop on the right, "
            "connected by a thin golden thread line across a dark navy background. "
            "In the center, a small server icon sits between them holding the connection state. "
            "Subtle circuit-board patterns in the background. "
            "Warm gold and cool blue accents on a deep navy field. "
            "Style: clean editorial tech illustration. No text. Professional and precise."
        ),
        "out": "/home/administrator/site/public/images/articles/lc-local-first-agent-systems-stop-being-toys-when-they-can-survive-handoffs.png"
    },
    {
        "slug": "release-notes-changelog",
        "prompt": (
            "Editorial illustration for a software releases article. "
            "A glowing changelog document with version numbers and diff lines arranged vertically, "
            "each version glowing brighter as they stack upward like steps. "
            "Small icons for checkmarks, warnings, and deprecations appear as colored dots. "
            "Deep navy background with warm gold for additions and soft red for removals. "
            "Style: editorial infographic, clean and architectural. No text. Professional."
        ),
        "out": "/home/administrator/site/public/images/articles/lc-release-notes-are-starting-to-matter-more-than-launch-events.png"
    },
    {
        "slug": "ai-service-business-operators",
        "prompt": (
            "Editorial illustration for an AI services article. "
            "A human operator stands at a command desk watching multiple floating AI service panels, "
            "each showing task cards, calendar blocks, and notification bells being managed in real time. "
            "The panels orbit gently around the operator like a control center. "
            "Dark navy background with warm gold and cool blue accent lights. "
            "Style: editorial tech illustration. Approachable but professional. No text."
        ),
        "out": "/home/administrator/site/public/images/articles/lc-the-next-wave-of-ai-service-businesses-will-look-more-like-operators-than-agencies.png"
    },
    {
        "slug": "healthcare-scheduling-ops",
        "prompt": (
            "Editorial illustration for a home healthcare AI article. "
            "A shift scheduling board with time blocks and caregiver names on the left, "
            "morphing into a clean digital calendar grid on the right with green fill indicators. "
            "A subtle stethoscope icon and a small heart rate line in the corner. "
            "Warm teal and gold accents against a dark navy background. "
            "Style: clean editorial healthcare tech. Professional and clear. No text."
        ),
        "out": "/home/administrator/site/public/images/articles/art2-operations-center.jpg"
    },
    {
        "slug": "openclaw-server-ops",
        "prompt": (
            "Editorial illustration for an OpenClaw AI ops article. "
            "A dark server rack with warm amber indicator lights glowing in a row, "
            "connected by fine golden lines to floating skill icons floating above. "
            "A terminal cursor blinks at the top of the rack. "
            "Deep navy to near-black background with warm amber glow from the servers. "
            "Style: industrial editorial tech illustration. No text. Authoritative and dark."
        ),
        "out": "/home/administrator/site/public/images/articles/art7-amber-server.jpg"
    },
]

for art in images:
    out = art["out"]
    print(f"\nGenerating: {art['slug']}")
    try:
        resp = client.models.generate_images(
            model="imagen-4.0-generate-001",
            prompt=art["prompt"],
            config={"aspectRatio": "16:9"}
        )
        for image in resp.generated_images:
            tmp_png = out + ".tmp.png"
            with open(tmp_png, "wb") as f:
                f.write(image.image.image_bytes)
            # Convert to JPG if needed
            if out.endswith(".jpg"):
                img = Image.open(tmp_png).convert("RGB")
                img.save(out, "JPEG", quality=90)
                os.remove(tmp_png)
            else:
                os.rename(tmp_png, out)
            size = os.path.getsize(out)
            print(f"  SAVED: {out} ({size} bytes)")
    except Exception as e:
        print(f"  ERROR: {e}")

print("\nAll done.")
