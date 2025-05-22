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

%% --- PARTE 4.5: Eliminar huecos y rellenar losetas ---

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
title('Losetas rellenadas sin huecos internos')


%% --- PARTE 6: Visualizar cada cluster aplicado a la imagen original ---

figure;
for i = 1:k
    % Crear máscara del cluster i
    mask_i = (L_rellenado == i);
    
    % Aplicar máscara a la imagen original
    img_cluster = zeros(size(img), 'like', img);
    for c = 1:3
        canal = img(:,:,c);
        canal_masked = zeros(size(canal), 'like', canal);
        canal_masked(mask_i) = canal(mask_i);
        img_cluster(:,:,c) = canal_masked;
    end
    
    % Mostrar en un subplot
    subplot(2, 3, i); % 2 filas x 3 columnas
    imshow(img_cluster);
    title(['Cluster ', num2str(i)]);
end

sgtitle('Cada cluster aplicado a la imagen original');
