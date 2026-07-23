import os
import re
import json
import csv
import time
import urllib.request
import urllib.parse

def normalize_name(name):
    """Normalizes exercise name for exact/fuzzy matching."""
    return re.sub(r'[^a-z0-9]', '', name.lower())

def slugify(text):
    """Creates a clean filename slug from exercise name."""
    slug = text.lower()
    slug = re.sub(r'[^a-z0-9]+', '-', slug).strip('-')
    return slug

def get_youtube_link(exercise_name):
    """Fetches YouTube tutorial link for the exercise."""
    query = f"{exercise_name} exercise workout tutorial"
    encoded_query = urllib.parse.quote(query)
    url = f"https://www.youtube.com/results?search_query={encoded_query}"
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    
    try:
        req = urllib.request.Request(url, headers=headers)
        html = urllib.request.urlopen(req, timeout=5).read().decode('utf-8', errors='ignore')
        video_ids = re.findall(r"watch\?v=([a-zA-Z0-9_-]{11})", html)
        if video_ids:
            return f"https://www.youtube.com/watch?v={video_ids[0]}"
    except Exception:
        pass
        
    return f"https://www.youtube.com/results?search_query={encoded_query}"

def fetch_verified_exercise_db():
    """Fetches official public-domain free-exercise-db index from GitHub CDN."""
    db_url = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
    req = urllib.request.Request(db_url, headers={'User-Agent': 'Mozilla/5.0'})
    
    db_lookup = {}
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            for item in data:
                raw_name = item.get("name", "")
                images = item.get("images", [])
                if raw_name and images:
                    norm_key = normalize_name(raw_name)
                    # Build direct CDN URL for exercise image 0
                    img_path = images[0]
                    full_img_url = f"https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{img_path}"
                    db_lookup[norm_key] = full_img_url
    except Exception as e:
        print(f"[!] Warning: Could not load verified exercise database index: {e}")
        
    return db_lookup

def download_file(url, save_path):
    """Downloads verified image and validates minimum payload size."""
    headers = {'User-Agent': 'Mozilla/5.0'}
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status == 200:
                content = resp.read()
                # Ensure payload is a real image (>2KB) and not an HTML error
                if len(content) > 2000 and not content.startswith(b'<!DOCTYPE') and not content.startswith(b'<html'):
                    with open(save_path, 'wb') as f:
                        f.write(content)
                    return True
    except Exception:
        pass
    return False

def main():
    image_dir = "exercise_images"
    os.makedirs(image_dir, exist_ok=True)
    
    print("1. Loading verified public domain exercise database...")
    verified_db = fetch_verified_exercise_db()
    print(f"   Loaded {len(verified_db)} verified exercise image records.")
    
    print("2. Fetching exercise dataset...")
    json_url = "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/data/exercises.json"
    req = urllib.request.Request(json_url, headers={'User-Agent': 'Mozilla/5.0'})
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            exercises_data = json.loads(response.read().decode('utf-8'))
    except Exception as e:
        print(f"Failed to load dataset: {e}")
        return

    total_exercises = len(exercises_data)
    print(f"   Loaded {total_exercises} exercises to process.\n")
    
    csv_file = "exercises_verified_library.csv"
    matched_count = 0
    
    with open(csv_file, mode='w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        writer.writerow(["Exercise Name", "Filename", "YouTube Link"])
        
        for index, item in enumerate(exercises_data):
            name = item.get("name", "")
            if not name:
                continue
            
            norm_key = normalize_name(name)
            filename = ""
            
            # Match against verified exercise CDN
            if norm_key in verified_db:
                img_url = verified_db[norm_key]
                base_slug = slugify(name)
                filename = f"{base_slug}.jpg"
                file_path = os.path.join(image_dir, filename)
                
                success = download_file(img_url, file_path)
                if success:
                    matched_count += 1
                    print(f"[{index + 1}/{total_exercises}] MATCHED & DOWNLOADED: {name}")
                else:
                    filename = ""
                    print(f"[{index + 1}/{total_exercises}] Download error: {name}")
            else:
                print(f"[{index + 1}/{total_exercises}] Skipped (No verified exercise photo match): {name}")
                
            yt_link = get_youtube_link(name)
            writer.writerow([name, filename, yt_link])
            file.flush()
            time.sleep(0.05)

    print(f"\nCompleted! Downloaded {matched_count}/{total_exercises} verified gym exercise images.")
    print(f"CSV saved to '{csv_file}' and clean images saved to '{image_dir}/'.")

if __name__ == "__main__":
    main()