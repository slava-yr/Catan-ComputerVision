clc; clear; close all;

k = 6;  % Número de clusters (losetas)
umbral_area_min = 2500;
se_morph = strel('disk', 1);
se_fill = strel('disk', 8);

figure('Name', 'Losetas útiles con huecos rellenados');

for idx = 1:10
    %% --- 1: Cargar y suavizar imagen ---
    img = imread(sprintf('imgs2/catan %d.jpeg', idx));
    img_double = im2double(img);
    img_suave = imbilatfilt(img_double, 0.1, 5); 

    %% --- 2: Extraer solo el tablero ---
    lab = rgb2lab(img_suave);
    L_board = imsegkmeans(single(lab), 2, 'NumAttempts', 5);
    [m, n, ~] = size(img);
    centro = L_board(round(m/3):round(2*m/3), round(n/3):round(2*n/3));
    modo = mode(centro(:));
    mascara_tablero = L_board == modo;

    % Limpieza de la máscara
    mascara_tablero = imfill(mascara_tablero, 'holes');
    mascara_tablero = bwareaopen(mascara_tablero, 8000);
    mascara_tablero = imclose(mascara_tablero, strel('disk', 20));
    mascara_tablero = bwareafilt(mascara_tablero, 1);
    se_suavizar = strel('disk', 30);
    mascara_tablero = imopen(mascara_tablero, se_suavizar);
    mascara_tablero = imclose(mascara_tablero, se_suavizar);
    mascara_tablero = imerode(mascara_tablero, strel('disk', 25));

    % Aplicar máscara a imagen original
    img_tablero = img;
    for c = 1:3
        canal = img_tablero(:,:,c);
        canal(~mascara_tablero) = 0;
        img_tablero(:,:,c) = canal;
    end

    %% --- 3: Preprocesamiento: filtro bilateral + CLAHE ---
    lab = rgb2lab(img_tablero);
    L = lab(:,:,1); A = lab(:,:,2); B = lab(:,:,3);
    L_filt = imbilatfilt(L, 30, 10);
    A_filt = imbilatfilt(A, 30, 10);
    B_filt = imbilatfilt(B, 30, 10);
    L_clahe = adapthisteq(L_filt / 100, 'ClipLimit', 0.05, 'Distribution', 'uniform');
    alpha = 0.2;
    L_final = alpha * L_clahe * 100 + (1 - alpha) * L_filt;
    lab_filt = cat(3, L_final, A_filt, B_filt);
    img_bilateral = lab2rgb(lab_filt);
    img_bilateral = imgaussfilt(img_bilateral, 2);
    img_bilateral = imadjust(img_bilateral, [35/255 1], [0 1]);

    %% --- 4: Segmentación con k-means en YCbCr ---
    ycbcr_img = rgb2ycbcr(im2uint8(img_bilateral));
    L_kmeans = imsegkmeans(im2single(ycbcr_img), k);

    %% --- 5: Limpieza morfológica de clusters ---
    L_filtrado = zeros(size(L_kmeans), 'like', L_kmeans);
    for i = 1:k
        mask = (L_kmeans == i);
        mask = bwareaopen(mask, umbral_area_min);
        mask = imdilate(mask, se_morph);
        mask = imclose(mask, se_morph);
        mask = imerode(mask, se_morph);
        L_filtrado(mask) = i;
    end

    %% --- 6: Eliminar dos clusters dominantes de fondo ---
    stats = regionprops(L_filtrado, 'Area', 'PixelIdxList');
    [~, idx_max] = max([stats.Area]);
    cluster_fondo1 = L_filtrado(stats(idx_max).PixelIdxList(1));
    L_tmp = L_filtrado;
    L_tmp(L_tmp == cluster_fondo1) = 0;

    stats = regionprops(L_tmp, 'Area', 'PixelIdxList');
    [~, idx_max] = max([stats.Area]);
    cluster_fondo2 = L_tmp(stats(idx_max).PixelIdxList(1));
    L_tmp(L_tmp == cluster_fondo2) = 0;

    %% --- 7: Rellenar huecos en losetas útiles ---
    L_rellenado = zeros(size(L_tmp), 'like', L_tmp);
    etiquetas = unique(L_tmp); etiquetas(etiquetas == 0) = [];
    for i = 1:numel(etiquetas)
        mask = (L_tmp == etiquetas(i));
        mask_closed = imclose(mask, se_fill);
        mask_rellenado = imfill(mask_closed, 'holes');
        L_rellenado(mask_rellenado) = etiquetas(i);
    end

    %% --- 8: Visualización final ---
    subplot(2, 5, idx);
    imshow(label2rgb(L_rellenado, 'jet', 'k'));
    title(sprintf('Catan %d', idx));
end
