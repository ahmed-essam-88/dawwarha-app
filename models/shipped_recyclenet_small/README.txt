The scanner model shipped in the app (0.3.x and 0.4.x): recyclenet-small.onnx, sha256 6ef8f7f4d84395af7458731ead9d3f8aaf5ff54d49cfeab33a0f278b655e00d7.
Upstream: https://huggingface.co/LeoYan/recyclenet-mobilenetv3 (MIT per its model card). Our file differs from upstream in one byte, the ONNX ir_version header (10 upstream, 8 here). Full credit and notes: THIRD_PARTY_NOTICES.md in the source zip.
Outputs: cardboard, glass, metal, paper, plastic, trash. No organic output. Not trained by us.
