clear; close all; clc;

figure('Name','Imagen sin fondo (contorno)');
figure('Name','Máscara por K-means');
figure('Name','Tablero final limpio');

for i = 1:10
    % Leer imagen original
    I = imread(sprintf('imgs2/catan %d.jpeg', i));
    hsv = rgb2hsv(I);

    % --- PASO 1: Eliminar fondo por contorno convexo del mar ---
    mar_mask = (hsv(:,:,1) > 0.5 & hsv(:,:,1) < 0.7) & ...
               (hsv(:,:,2) > 0.4) & (hsv(:,:,3) > 0.3);
    mar_mask = imclose(imopen(mar_mask, strel('disk',5)), strel('disk',10));
    mar_mask = imfill(mar_mask,'holes');

    CC = bwconncomp(mar_mask);
    numPixels = cellfun(@numel, CC.PixelIdxList);
    mask_largest = false(size(mar_mask));
    if ~isempty(numPixels)
        mask_largest(CC.PixelIdxList{numPixels == max(numPixels)}) = true;
    end

    [y,x] = find(bwperim(mask_largest));
    if numel(x) >= 3
        K = convhull(x, y);
        mask_poly = poly2mask(x(K), y(K), size(mar_mask,1), size(mar_mask,2));
    else
        mask_poly = false(size(mar_mask));
    end

    img_sin_fondo = I;
    for c = 1:3
        canal = img_sin_fondo(:,:,c);
        canal(~mask_poly) = 0;
        img_sin_fondo(:,:,c) = canal;
    end

    figure(1); subplot(2,5,i);
    imshow(img_sin_fondo); title(sprintf('Sin fondo %d', i));

    % --- PASO 2: Extraer el tablero con K-means Lab sobre img_sin_fondo ---

    imagen = img_sin_fondo;
    imagen_double = im2double(imagen);

    % Suavizado
    imagen_suave = imbilatfilt(imagen_double, 1, 5);

    % K-means en espacio Lab
    lab = rgb2lab(imagen_suave);
    L = imsegkmeans(single(lab), 2, 'NumAttempts', 5);

    % Elegir el cluster del centro como tablero
    [m, n, ~] = size(imagen);
    centro = L(round(m/3):round(2*m/3), round(n/3):round(2*n/3));
    modo = mode(centro(:));
    mascara_tablero = (L == modo);

    % Morfología
    mascara_tablero = imfill(mascara_tablero, 'holes');
    mascara_tablero = bwareaopen(mascara_tablero, 8000);
    se = strel('disk', 5);
    mascara_tablero = imclose(mascara_tablero, se);
    mascara_tablero = bwareafilt(mascara_tablero, 1);
    mascara_tablero = imopen(mascara_tablero, se);
    mascara_tablero = imerode(mascara_tablero, strel('disk', 30));

    figure(2); subplot(2,5,i);
    imshow(mascara_tablero); title(sprintf('Máscara tablero %d', i));

    % Aplicar la máscara final
    imagen_segmentada = imagen;
    for c = 1:3
        canal = imagen_segmentada(:,:,c);
        canal(~mascara_tablero) = 0;
        imagen_segmentada(:,:,c) = canal;
    end

    figure(3); subplot(2,5,i);
    imshow(imagen_segmentada); title(sprintf('Final limpio %d', i));

    % Guardar si se desea
    % imwrite(imagen_segmentada, sprintf('salidas/final_tablero_%d.png', i));
end
