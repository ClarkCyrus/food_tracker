import json
labels = [l.strip() for l in open("labels.txt","r",encoding="utf-8") if l.strip()]
template = {lbl: {
    "serving_g": None,
    "per_serving": {"kcal": None, "protein_g": None, "fat_g": None, "carbs_g": None},
    "per_100g": {"kcal": None, "protein_g": None, "fat_g": None, "carbs_g": None},
    "notes": "fill with verified values"
} for lbl in labels}
with open("nutrients.json","w",encoding="utf-8") as f:
    json.dump(template, f, indent=2, ensure_ascii=False)
print("Wrote nutrients.json template for", len(labels), "labels")
