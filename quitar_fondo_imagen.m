clear; close all; clc;

% Leer imagen (cambia el nombre o ruta según necesites)
I = imread('imgs2/catan 1.jpeg');

% Convertir a HSV
hsv = rgb2hsv(I);

% Máscara del mar basada en color
mar_mask = (hsv(:,:,1)>0.5 & hsv(:,:,1)<0.7) & (hsv(:,:,2)>0.4) & (hsv(:,:,3)>0.3);

% Limpiar máscara con operaciones morfológicas
mar_mask = imclose(imopen(mar_mask, strel('disk',5)), strel('disk',10));
mar_mask = imfill(mar_mask,'holes');

% Componentes conectados
CC = bwconncomp(mar_mask);
numPixels = cellfun(@numel, CC.PixelIdxList);

% Obtener la región más grande
mask_largest = false(size(mar_mask));
if ~isempty(numPixels)
    mask_largest(CC.PixelIdxList{numPixels == max(numPixels)}) = true;
end

% Encontrar perímetro
[y,x] = find(bwperim(mask_largest));

% Calcular polígono convexo
if numel(x) >= 3
    K = convhull(x, y);
else
    K = [];
end

% Crear máscara poligonal
if ~isempty(K)
    mask_poly = poly2mask(x(K), y(K), size(mar_mask,1), size(mar_mask,2));
else
    mask_poly = false(size(mar_mask));
end

% Aplicar máscara a la imagen original (element-wise multiplicación para RGB)
I_recortada = I;
for c = 1:3
    canal = I(:,:,c);
    canal(~mask_poly) = 0;  % Poner a negro fuera del polígono
    I_recortada(:,:,c) = canal;
end

% Mostrar resultado
figure('Name','Imagen Recortada con Máscara Poligonal','NumberTitle','off');
imshow(I_recortada);
title('Imagen recortada aplicando la máscara poligonal');

% Limpiar variables, excepto las necesarias
clearvars -except mask_poly I_recortada