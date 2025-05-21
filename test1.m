clc; clear; close all;
% Objetivo:
% Detectar los 6 tipos de loseta: Bosque, Pasto, Montaña, Colina, Campo,
% Desierto
%% --- 1: Cargar imagen ---
img = imread('imgs/catan 6.jpeg');  
[h, w, ~] = size(img);
figure; imshow(img); title('Imagen original');

%% --- PARTE 2: Preprocesamiento ---
% Contrast stretching
img_stretch = imadjust(im2double(img), stretchlim(im2double(img)), []);
% Filtro bilateral
img_bilateral = imbilatfilt(img_stretch, 0.2, 3);

figure; imshow(img_bilateral); title('Imagen preprocesada');

k = 8;

%% --- PARTE 3: Detección de regiones ---
% --- 3. Segmentación en diferentes espacios de color ---

% RGB
rgb_img = im2single(img);
L_rgb = imsegkmeans(rgb_img, k);

% Lab
lab_img = rgb2lab(img);
lab_img_single = im2single(lab_img);
L_lab = imsegkmeans(lab_img_single, k);

% HSV
hsv_img = rgb2hsv(img);
hsv_img_single = im2single(hsv_img);
L_hsv = imsegkmeans(hsv_img_single, k);

% YCbCr
ycbcr_img = rgb2ycbcr(img);
ycbcr_img_single = im2single(ycbcr_img);
L_ycbcr = imsegkmeans(ycbcr_img_single, k);

% Solo canales a/b de Lab (color sin luminancia)
lab_ab = lab_img(:,:,2:3);  % canales a y b
lab_ab_single = im2single(lab_ab);
L_lab_ab = imsegkmeans(lab_ab_single, k);

%% --- 4. Visualizar resultados ---
figure('Name', 'Comparación de segmentaciones', 'Position', [100, 100, 1200, 800]);

subplot(2,3,1);
imshow(img);
title('Original');

subplot(2,3,2);
imshow(label2rgb(L_rgb));
title('Segmentación RGB');

subplot(2,3,3);
imshow(label2rgb(L_lab));
title('Segmentación Lab');

subplot(2,3,4);
imshow(label2rgb(L_hsv));
title('Segmentación HSV');

subplot(2,3,5);
imshow(label2rgb(L_ycbcr));
title('Segmentación YCbCr');

subplot(2,3,6);
imshow(label2rgb(L_lab_ab));
title('Segmentación Lab a/b');

