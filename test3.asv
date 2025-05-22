clc; clear; close all;

% Objetivo:
% Detectar los 6 tipos de loseta: Bosque, Pastos, Montaña, Cantera, Cultivos, Desierto

%% --- 1: Cargar imagen ---
img = imread('hola.png');  
[h, w, ~] = size(img);
figure; imshow(img); title('Imagen original');

%% --- 2: Preprocesamiento ---
img_bilateral = imbilatfilt(img, 0.2, 3);
figure; imshow(img_bilateral); title('Imagen suavizada con filtro bilateral');

%% --- 3: Segmentación con k-means en espacio YCbCr ---
k = 6;  % Número de clusters (losetas)
ycbcr_img = rgb2ycbcr(img_bilateral);
L_kmeans = imsegkmeans(im2single(ycbcr_img), k);

figure; imshow(label2rgb(L_kmeans, 'jet', 'k'));
title('Segmentación inicial con k-means');

%% --- 4: Filtrado morfológico por cluster ---
umbral_area_min = 1500;  % Área mínima para filtrar objetos pequeños
se = strel('disk', 5);
L_filtrado = zeros(size(L_kmeans), 'like', L_kmeans);

for i = 1:k
    mask = (L_kmeans == i);
    mask = bwareaopen(mask, umbral_area_min);  % Eliminar regiones pequeñas
    mask = imdilate(mask, se);
    mask = imclose(mask, se);
    mask = imerode(mask, se);
    L_filtrado(mask) = i;
end

figure; imshow(label2rgb(L_filtrado, 'jet', 'k'));
title('Segmentación tras limpieza morfológica');

%% --- 5: Eliminar fondo (primer cluster dominante) ---
stats = regionprops(L_filtrado, 'Area', 'PixelIdxList');
[~, idx_max] = max([stats.Area]);
cluster_fondo = L_filtrado(stats(idx_max).PixelIdxList(1));
L_sin_fondo = L_filtrado;
L_sin_fondo(L_filtrado == cluster_fondo) = 0;

figure; imshow(label2rgb(L_sin_fondo, 'jet', 'k'));
title('Sin el primer fondo (negro o dominante)');

%% --- 6: Eliminar segundo fondo (borde/tablero) ---
stats = regionprops(L_sin_fondo, 'Area', 'PixelIdxList');
[~, idx_max] = max([stats.Area]);
cluster_fondo2 = L_sin_fondo(stats(idx_max).PixelIdxList(1));
L_sin_fondo2 = L_sin_fondo;
L_sin_fondo2(L_sin_fondo == cluster_fondo2) = 0;

figure; imshow(label2rgb(L_sin_fondo2, 'jet', 'k'));
title('Sin el segundo fondo (tablero u otro)');

%% --- 7: Rellenar huecos dentro de las losetas útiles ---
L_rellenado = zeros(size(L_sin_fondo2), 'like', L_sin_fondo2);
etiquetas = unique(L_sin_fondo2);
etiquetas(etiquetas == 0) = [];  % Omitir fondo

for i = 1:numel(etiquetas)
    mask = (L_sin_fondo2 == etiquetas(i));
    mask_rellenado = imfill(mask, 'holes');
    L_rellenado(mask_rellenado) = etiquetas(i);
end

figure; imshow(label2rgb(L_rellenado, 'jet', 'k'));
title('Losetas útiles con huecos rellenados');
