import os
import sys
from PIL import Image

def slice_sprite_sheet(image_path, output_dir, direction, frames=6):
    """
    Slices a horizontal sprite sheet into 'frames' number of equal parts.
    Saves them as duck-walk-{direction}-{i}.png in output_dir.
    """
    try:
        img = Image.open(image_path)
    except Exception as e:
        print(f"Error opening {image_path}: {e}")
        return

    width, height = img.size
    frame_width = width // frames
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    for i in range(frames):
        left = i * frame_width
        right = left + frame_width
        # Box is (left, top, right, bottom)
        box = (left, 0, right, height)
        
        frame_img = img.crop(box)
        
        filename = f"duck-walk-{direction}-{i+1}.png"
        out_path = os.path.join(output_dir, filename)
        
        frame_img.save(out_path)
        print(f"Saved {out_path}")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python slice_sprites.py <image_path> <output_dir> <direction> [frames]")
        sys.exit(1)

    image_path = sys.argv[1]
    output_dir = sys.argv[2]
    direction = sys.argv[3]
    frames = int(sys.argv[4]) if len(sys.argv) > 4 else 6

    slice_sprite_sheet(image_path, output_dir, direction, frames)
