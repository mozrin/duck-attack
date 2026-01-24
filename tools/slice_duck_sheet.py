import os
import sys
from PIL import Image, ImageOps

def slice_duck_sheet():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    image_path = os.path.join(base_dir, 'assets', 'images', 'duck', 'duck-walk-sheet.png')
    output_dir = os.path.join(base_dir, 'assets', 'images', 'duck', 'walk')
    
    if not os.path.exists(image_path):
        print(f"Error: Could not find {image_path}")
        return

    os.makedirs(output_dir, exist_ok=True)

    try:
        img = Image.open(image_path).convert('RGBA')
        # Load as greyscale for thresholding
        gray = img.convert('L')
        # Threshold to find ink (black pixels) - assuming white background
        # Pixels < 200 are considered 'ink'
        threshold = 200
        # Invert so ink is white (255) and background is black (0) for projection
        bw = gray.point(lambda x: 255 if x < threshold else 0, '1')
    except Exception as e:
        print(f"Error loading image: {e}")
        return

    width, height = img.size
    pixels = bw.load()

    # 1. Horizontal Projection to find Rows
    row_sums = []
    for y in range(height):
        row_sum = 0
        for x in range(width):
            if pixels[x, y]:
                row_sum += 1
        row_sums.append(row_sum)

    # Find row ranges (segments with high pixel density)
    image_row_regions = []
    in_row = False
    start_y = 0
    min_row_height = 20  # Minimum height to consider a valid row
    
    for y, count in enumerate(row_sums):
        if count > 10: # Threshold for line content
            if not in_row:
                in_row = True
                start_y = y
        else:
            if in_row:
                in_row = False
                if y - start_y > min_row_height:
                    image_row_regions.append((start_y, y))

    print(f"Detected {len(image_row_regions)} rows.")

    # We expect 8 rows. If we found more, maybe we need to filter?
    # Or strict mapping.
    directions = ['n', 's', 'e', 'w', 'se', 'sw', 'ne', 'nw']
    
    if len(image_row_regions) != 8:
        print("Warning: Did not detect exactly 8 rows. Attempting to use grid estimation.")
        # Fallback: divide height by 8
        row_height = height // 8
        image_row_regions = [(i * row_height, (i + 1) * row_height) for i in range(8)]

    for row_idx, (r_start, r_end) in enumerate(image_row_regions):
        if row_idx >= len(directions):
            break
        
        direction = directions[row_idx]
        
        # 2. Vertical Projection within this row to find columns
        # We need to skip the label on the left.
        col_sums = []
        for x in range(width):
            col_sum = 0
            for y in range(r_start, r_end):
                if pixels[x, y]:
                    col_sum += 1
            col_sums.append(col_sum)

        col_regions = []
        in_col = False
        start_x = 0
        min_col_width = 20

        for x, count in enumerate(col_sums):
            if count > 5:
                if not in_col:
                    in_col = True
                    start_x = x
            else:
                if in_col:
                    in_col = False
                    if x - start_x > min_col_width:
                        col_regions.append((start_x, x))
        
        # Expecting Label + 6 frames = 7 columns.
        # We want the last 6.
        frames_to_process = col_regions
        
        # Simple heuristic: ignore the first column if we have > 6 columns
        # Or if the first column is very far left.
        
        valid_frames = []
        
        # Filter regions that are likely frames
        for cx_start, cx_end in col_regions:
            # Check aspect ratio or something? 
            # Or just take the last 6 found?
            valid_frames.append((cx_start, cx_end))
            
        if len(valid_frames) > 6:
            valid_frames = valid_frames[-6:]
        
        print(f"Row {row_idx} ({direction}): Found {len(valid_frames)} frames.")

        for frame_idx, (c_start, c_end) in enumerate(valid_frames):
            # Extract the cell
            # Refine bounding box within the cell
            cell_box = (c_start, r_start, c_end, r_end)
            cell_crop = img.crop(cell_box)
            cell_bw = bw.crop(cell_box)
            
            bbox = cell_bw.getbbox()
            if bbox:
                # bbox is relative to cell_crop
                abs_box = (c_start + bbox[0], r_start + bbox[1], c_start + bbox[2], r_start + bbox[3])
                
                # Center point of the detected content
                center_x = (abs_box[0] + abs_box[2]) // 2
                center_y = (abs_box[1] + abs_box[3]) // 2
                
                # We want 50x50 output
                half_size = 25
                final_crop_box = (
                    center_x - half_size,
                    center_y - half_size,
                    center_x + half_size,
                    center_y + half_size
                )
                
                final_sprite = img.crop(final_crop_box)
                
                filename = f"duck-walk-{direction}-{frame_idx + 1}.png"
                out_path = os.path.join(output_dir, filename)
                final_sprite.save(out_path)
                # print(f"Saved {out_path}")

if __name__ == "__main__":
    slice_duck_sheet()
