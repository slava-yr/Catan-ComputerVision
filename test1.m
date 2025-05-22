clc; clear; close all;
% Objetivo:
% Detectar los 6 tipos de loseta: Bosque, Pastos, Montaña, Cantera, Cultivos,
% Desierto
%% --- 1: Cargar imagen ---
img = imread('hola.png');  
[h, w, ~] = size(img);
figure; imshow(img); title('Imagen original');

%% --- PARTE 2: Preprocesamiento ---
% Contrast stretching
img_stretch = imadjust(im2double(img), stretchlim(im2double(img)), []);
% Filtro bilateral
img_bilateral = imbilatfilt(img_stretch, 0.2, 3);

figure; imshow(img_bilateral); title('Imagen preprocesada');

k = 7;
%% --- PARTE 3: Detección de regiones ---
% --- 3. Segmentación en diferentes espacios de color --
% YCbCr
ycbcr_img = rgb2ycbcr(img);
ycbcr_img_single = im2single(ycbcr_img);
L_ycbcr = imsegkmeans(ycbcr_img_single, k);


%% --- 4. Visualizar resultados ---

figure;imshow(label2rgb(L_ycbcr));title('Segmentación YCbCr');