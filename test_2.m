clc; clear; close all;
% Objetivo:
% Detectar los 6 tipos de loseta: Bosque, Pastos, Montaña, Cantera, Cultivos, Desierto

%% --- 1: Cargar imagen ---
img = imread('hola.png');  
[h, w, ~] = size(img);
figure; imshow(img); title('Imagen original');

%% --- PARTE 2: Preprocesamiento ---
% Filtro bilateral para suavizar y reducir ruido/reflejos
img_bilateral = imbilatfilt(img, 0.2, 3);
figure; imshow(img_bilateral); title('Imagen preprocesada');

k = 6; % número de clusters (losetas)

%% --- PARTE 3: Segmentación con k-means en espacio YCbCr ---
ycbcr_img = rgb2ycbcr(img_bilateral);
ycbcr_img_single = im2single(ycbcr_img);
L_ycbcr = imsegkmeans(ycbcr_img_single, k);

%% --- PARTE 4: Filtrado y limpieza por cluster ---

% Parámetros para filtrado de áreas
umbral_area_min = 1500;  % ajustar según tamaño esperado de una loseta
% umbral_area_max = 15000; % si quieres eliminar regiones demasiado grandes

L_filtrado = zeros(size(L_ycbcr), 'like', L_ycbcr);

for i = 1:k
    mask_i = (L_ycbcr == i);

    % ---------------- NUEVO: eliminar regiones pequeñas ----------------
    mask_i = bwareaopen(mask_i, umbral_area_min);
    
    % Morfología para unir fragmentos de la misma loseta
    se = strel('disk', 5);
    mask_i = imdilate(mask_i, se);
    mask_i = imclose(mask_i, se);
    mask_i = imerode(mask_i, se);  % volver al tamaño aproximado original
    
    % Añadir al resultado final con el índice de cluster i
    L_filtrado(mask_i) = i;
end

%% --- PARTE 5: Visualización resultados limpiados ---
figure; imshow(label2rgb(L_filtrado, 'jet', 'k'));
title('Segmentación YCbCr tras filtrado y limpieza de clusters');

%% --- PARTE 4.5: Eliminar huecos azules internos y rellenar losetas ---
L_rellenado = zeros(size(L_filtrado), 'like', L_filtrado);

for i = 1:k
    mask_i = (L_filtrado == i);
    mask_i_relleno = imfill(mask_i, 'holes');
    L_rellenado(mask_i_relleno) = i;
end

%% --- PARTE 5: Visualización resultados rellenados ---
figure; imshow(label2rgb(L_rellenado, 'jet', 'k'));
title('Losetas rellenadas sin huecos internos');
