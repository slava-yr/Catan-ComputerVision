[h, w, ~] = size(img);
figure; imshow(img); title('Imagen original');

% --- 2. Preprocesamiento común ---
img_stretch = imadjust(img, stretchlim(img), []);
img_filtered = imbilatfilt(img_stretch, 0.2, 3);

% --- 3. SEGMENTACIÓN CON HSV ---
hsv_img = rgb2hsv(img_filtered);  % HSV
H = hsv_img(:,:,1);  % Matiz
S = hsv_img(:,:,2);  % Saturación
V = hsv_img(:,:,3);  % Valor

% Normalizar
H_norm = rescale(H);
S_norm = rescale(S);
V_norm = rescale(V);

hsv_combined = cat(3, H_norm, S_norm, V_norm);
hsv_combined = im2single(hsv_combined);

k = 7;
[L_hsv, ~] = imsegkmeans(hsv_combined, k, 'NumAttempts', 3);

% Visualización HSV
rgb_hsv = label2rgb(L_hsv);
overlay_hsv = imfuse(img, rgb_hsv, 'blend');

figure;
subplot(1,2,1); imshow(rgb_hsv); title('Segmentación HSV');
subplot(1,2,2); imshow(overlay_hsv); title('Superposición HSV');

% --- 4. SEGMENTACIÓN CON LAB ---
lab_img = rgb2lab(img_filtered);  % Lab
a = lab_img(:,:,2);
b = lab_img(:,:,3);

a_norm = rescale(a);
b_norm = rescale(b);

lab_combined = cat(3, a_norm, b_norm);  % L excluido para evitar luz/flash
lab_combined = im2single(lab_combined);

[L_lab, ~] = imsegkmeans(lab_combined, k, 'NumAttempts', 3);

% Visualización Lab
rgb_lab = label2rgb(L_lab);
overlay_lab = imfuse(img, rgb_lab, 'blend');

figure;
subplot(1,2,1); imshow(rgb_lab); title('Segmentación Lab');
subplot(1,2,2); imshow(overlay_lab); title('Superposición Lab');