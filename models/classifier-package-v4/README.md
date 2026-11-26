# Dawwarha classifier work: package (v4 model + reproduction)

## What is shipped here
- model/dooreha_candidate_v4_final.onnx  sha256 1965fa7edd4094eba0677af6f03d95babf683d159f7ba2877b40ea1d848c3432 (16.9 MB)
- scripts/   code used to select, download, extract features, fit, export and evaluate (run order: sel.py, dl.py/dl2.py, feat.py, build.py ... build4.py, ev.py; audit.py, bb.py, filt*.py were used for the box and visual audits). Paths in scripts point to the original working folders and need adjusting.
- data/splits.csv  every image id with its source, class and role (fit or holdout). data/v4_keep.json = the 246 Open Images ids kept for v4. data/v3_keep.json = the 288 kept for v3. data/single_item_fit_ids.csv = the 714 box-verified ids used for v2.
- audit/  v3_visual_audit.csv (keep/reject per image, 714 v2 images) and v4_second_pass_audit.csv (second pass over the 288 kept).
- credits/  CREDITS.txt (v4), v4_openimages_attribution_246.csv (author + landing URL + CC BY 2.0 per image), licence texts (TrashNet MIT, MIIL MIT, timm Apache-2.0). data/v1_openimages_attribution_all_...csv is the v1 manifest, kept for provenance only.

## Model contract (v4)
Input "image": float32 [N,3,224,224], RGB, value = pixel/255 only (no ImageNet mean/std), stretched resize to 224x224 (no crop). Output "logits" [N,5], order: glass, metal, paper, plastic, trash (paper includes cardboard). Softmax in the app. ONNX IR 8, opset 12. Backbone: timm mobilenetv3_large_100.miil_in21k_ft_in1k, frozen; head = linear layer (L2-regularised logistic regression, standardisation folded in), trained on CPU.
NO organic output.

## Training data
TrashNet (MIT) 80% split, seed 0: 2,023 images, plus 246 Open Images images (CC BY 2.0 per image; 171 metal, 75 glass) kept after a box audit and two visual audit passes. Plastic, paper and trash come from TrashNet only (Open Images "plastic" images were all bags, so none were used).

## Results (v4)
- TrashNet 20% holdout (504): 90.3% accuracy, 0.863 macro-F1.
- Open Images glass+metal holdout (n=133, box-verified, not visually audited): 91.0%.
- Measured end to end through the ONNX. Not tested on a phone. Dart/app parity was not run for v4.
- For reference, v1 vs shipped RecycleNet-small on the same holdouts: TrashNet 87.7% vs 82.5%.

## Limits and unresolved items
1. Backbone licence line is UNRESOLVED. The repackager's model card says Apache-2.0, but the weights were pretrained on ImageNet-21K-P, whose terms are non-commercial research/educational access, and the publisher states nothing on weights. Do not treat the model as cleared for commercial use.
2. No organic class: the Open Images "organic" images were bread, cooked dishes, drawings and whole produce, not food waste. Organic is an unmet requirement and needs new data.
3. Plastic has no bottle images beyond TrashNet. The kept Open Images items are product photos (full bottles, branded cans), not dirty or crushed waste.
4. The keep lists are one reviewer's judgment on thumbnails (160-204 px). Some kept images show a hand or a second object. TrashNet has near-duplicate objects across its splits, so the TrashNet number may be optimistic.
5. Heldouts have no Egyptian household waste photos.
6. TACO was not used (its upstream image licences are not cleared).

## Earlier versions (not shipped)
- v1 07c5901c61cd597b6b0f77cdb274c2685335a3714d65315d8a340d15de4f8b8e: 6 classes incl. organic, trained on 4,579 unaudited Open Images; the audit showed most were scenes or groups, not single items, and organic was not waste.
- v2 36d7ce22c7bc36d603a447a8f7f7f333503c599236f485f048bb1d6c86ad3c34: only 714 box-verified Open Images; visual check showed plastic = all bags and organic = food or art, glass = alcohol bottles with other objects.
- v3 a7d64c3c3357595a3eb60eaabc6789de0a8522bd0ccd970ea54daff0889d7906: 5 classes, 288 visually kept images (TrashNet 90.1%); a second pass removed 42 more.
- v4 (this package): second-pass cleaned, 246 kept images.
