clc; clear; close all;

% Objetivo:
% Detectar los 6 tipos de loseta: Bosque, Pastos, Montaña, Cantera, Cultivos, Desierto

%% --- 1: Cargar imagen ---
img = imread('imgs2/hola1.png');  
[h, w, ~] = size(img);
figure; imshow(img); title('Imagen original');

%% --- 2: Preprocesamiento: filtro bilateral en LAB y CLAHE en L ---
lab = rgb2lab(img);

L = lab(:,:,1);
A = lab(:,:,2);
B = lab(:,:,3);

% Filtro bilateral para suavizar sin perder bordes
L_filt = imbilatfilt(L, 30, 10);
A_filt = imbilatfilt(A, 30, 10);
B_filt = imbilatfilt(B, 30, 10);

% Aplicar CLAHE agresivo en L suavizado
L_clahe = adapthisteq(L_filt / 100, 'ClipLimit', 0.05, 'Distribution', 'uniform');

% Mezclar CLAHE con L suavizado original para controlar efecto
alpha = 0.2; % peso a CLAHE
L_final = alpha * L_clahe * 100 + (1 - alpha) * L_filt;

% Reconstruir imagen LAB y convertir a RGB
lab_filt = cat(3, L_final, A_filt, B_filt);
img_bilateral = lab2rgb(lab_filt);
img_bilateral=imgaussfilt(img_bilateral,2);
%img_bilateral=imadjust(img_bilateral,[70/255 255/255],[0 1]);
figure; imshow(img_bilateral); title('Imagen suavizada con filtro bilateral y CLAHE mezclado');

%% --- 3: Segmentación con k-means en espacio YCbCr ---
k = 6;  % Número de clusters (losetas)
ycbcr_img = rgb2ycbcr(im2uint8(img_bilateral)); % imsegkmeans espera uint8 para rgb2ycbcr
L_kmeans = imsegkmeans(im2single(ycbcr_img), k);

figure; imshow(label2rgb(L_kmeans, 'jet', 'k'));
title('Segmentación inicial con k-means');

%% --- 4: Filtrado morfológico por cluster ---
umbral_area_min = 2500;  % Área mínima para filtrar objetos pequeños
se = strel('disk', 2);
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

% Define aquí el elemento estructurante con el radio que mejor funcione
se = strel('disk', 2);   % prueba radios 1,2,3,… hasta que cierre bien el contorno

for i = 1:numel(etiquetas)
    mask = (L_sin_fondo2 == etiquetas(i));
    % 1) Cerrar pequeños orificios en el contorno
    mask_closed = imclose(mask, se);
    mask_rellenado = imfill(mask_closed, 'holes');
    L_rellenado(mask_rellenado) = etiquetas(i);
end

figure; imshow(label2rgb(L_rellenado, 'jet', 'k'));
title('Losetas útiles con huecos rellenados');

%% --- 8: Extraer solo las losetas desde la imagen original usando la máscara ---

% Crear una máscara binaria a partir de L_rellenado
mascara_binaria = L_rellenado > 0;

% Aplicar máscara por canal
img_losetas = img;
for c = 1:3
    canal = img(:,:,c);
    canal(~mascara_binaria) = 0;
    img_losetas(:,:,c) = canal;
end

figure; imshow(img_losetas);
title('Imagen original con solo las losetas extraídas');
