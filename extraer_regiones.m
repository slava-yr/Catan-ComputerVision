clc; clear; close all;
% Objetivo:
% Detectar los 6 tipos de loseta: Bosque, Pastos, Montaña, Cantera, Cultivos,
% Desierto

%% --- 1: Cargar imagen ---
img = imread('hola.png');  
[h, w, ~] = size(img);
figure; imshow(img); title('Imagen original');

%% --- PARTE 2: Preprocesamiento ---
% Filtro bilateral para suavizar y reducir ruido/reflejos
%img_bilateral = imbilatfilt(img, 20, 10);
%figure; imshow(img_bilateral); title('Imagen preprocesada');

k = 6; % número de clusters (losetas)

%%
% 1. Convertir a ycbcr
img_ycbcr = rgb2ycbcr(img);
Y = img_ycbcr(:,:,1);  % Canal de luminancia

% 2. Aplicar filtro bilateral solo a Y
Y_filtered = imbilatfilt(Y, 20, 15);

% 3. Visualizar canal Y original y filtrado
figure;
subplot(1,2,1); imshow(Y); title('Canal Y original');
subplot(1,2,2); imshow(Y_filtered); title('Canal Y filtrado');

% 4. Reconstruir imagen YCbCr con Y filtrado
img_ycbcr_filtered = img_ycbcr;
img_ycbcr_filtered(:,:,1) = Y_filtered;

% 5. Visualizar imagen reconstruida en RGB
img_filtered_rgb = ycbcr2rgb(img_ycbcr_filtered);
figure;
subplot(1,2,1); imshow(img); title('Original RGB');
subplot(1,2,2); imshow(img_filtered_rgb); title('RGB con Y filtrado');

% 6. Preparar imagen para segmentación
ycbcr_img_single = im2single(img_ycbcr_filtered);

% 7. Segmentar con k-means
L_ycbcr = imsegkmeans(ycbcr_img_single, k);

% 8. Visualizar la segmentación
figure;
imshow(label2rgb(L_ycbcr)); title(['Segmentación k-means (k = ', num2str(k), ')']);


%% --- PARTE 4: Filtrado y limpieza por cluster ---

% Parámetros para filtrado de áreas
umbral_area_min = 1500;  % ajustar según tamaño esperado de una loseta
% umbral_area_max = 15000; % si quieres eliminar regiones demasiado grandes

L_filtrado = zeros(size(L_ycbcr), 'like', L_ycbcr);

for i = 1:k
    mask_i = (L_ycbcr == i);
    
    % Filtrar regiones pequeñas (elimina ruido)
    mask_i = bwareaopen(mask_i, umbral_area_min);
    
    % Morfología para unir fragmentos de la misma loseta
    se = strel('disk', 5);
    mask_i = imdilate(mask_i, se);
    mask_i = imclose(mask_i, se);
    % Opcional: erosionar para volver al tamaño original o cercano
    mask_i = imerode(mask_i, se);
    
    % Añadir al resultado final con el índice de cluster i
    L_filtrado(mask_i) = i;
end

%% --- PARTE 5: Visualización resultados limpiados ---
figure; imshow(label2rgb(L_filtrado, 'jet', 'k'));
title('Segmentación YCbCr tras filtrado y limpieza de clusters');

%% --- PARTE 4.5: Eliminar huecos azules internos y rellenar losetas ---

% Crear una nueva matriz para las losetas completas y sin huecos
L_rellenado = zeros(size(L_filtrado), 'like', L_filtrado);

for i = 1:k
    % Máscara del cluster i
    mask_i = (L_filtrado == i);

    % Rellenar huecos (elimina agujeros dentro de la loseta)
    mask_i_relleno = imfill(mask_i, 'holes');

    % Guardar en resultado final con el mismo índice de cluster
    L_rellenado(mask_i_relleno) = i;
end

%% --- PARTE 5: Visualización resultados rellenados ---
figure; imshow(label2rgb(L_rellenado, 'jet', 'k'));
title('Losetas rellenadas sin huecos internos');
