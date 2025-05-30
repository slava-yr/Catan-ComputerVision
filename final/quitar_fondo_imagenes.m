clear; close all; clc;

% Leer imagen
I = imread('imgs2/catan 3.jpeg');

%% 1. Convertir a HSV
hsv = rgb2hsv(I);

% Mostrar los tres canales HSV
figure('Name','Espacio HSV','NumberTitle','off');
subplot(1,3,1); imshow(hsv(:,:,1)); title('Hue');
subplot(1,3,2); imshow(hsv(:,:,2)); title('Saturation');
subplot(1,3,3); imshow(hsv(:,:,3)); title('Value');

% Convertir a HSV
hsv_img = rgb2hsv(I);

% Mostrar HSV convertido de nuevo a RGB (para ver la diferencia)
figure('Name','Visualización del espacio HSV','NumberTitle','off');
imshow(hsv2rgb(hsv_img));
title('Imagen en espacio HSV (visualizado como RGB)');


%% 2. Máscara del mar basada en color
mar_mask = (hsv(:,:,1)>0.5 & hsv(:,:,1)<0.7) & ...
           (hsv(:,:,2)>0.4) & ...
           (hsv(:,:,3)>0.3);

% Limpieza morfológica
mar_mask_clean = imclose(imopen(mar_mask, strel('disk',5)), strel('disk',10));
mar_mask_clean = imfill(mar_mask_clean,'holes');

% Mostrar máscaras
figure('Name','Máscara del mar y limpieza','NumberTitle','off');
subplot(1,2,1); imshow(mar_mask); title('Máscara inicial (color azul)');
subplot(1,2,2); imshow(mar_mask_clean); title('Máscara limpia');

%% 3. Componentes conectados y región más grande
CC = bwconncomp(mar_mask_clean);
numPixels = cellfun(@numel, CC.PixelIdxList);

mask_largest = false(size(mar_mask));
if ~isempty(numPixels)
    mask_largest(CC.PixelIdxList{numPixels == max(numPixels)}) = true;
end

% Mostrar región conectada más grande
figure('Name','Región más grande conectada','NumberTitle','off');
imshow(mask_largest);
title('Región más grande conectada (posible mar)');

%% 4. Encontrar perímetro y polígono convexo
[y,x] = find(bwperim(mask_largest));

if numel(x) >= 3
    K = convhull(x, y);
else
    K = [];
end

% Mostrar contorno y polígono sobre la imagen
figure('Name','Contorno y Polígono Convexo','NumberTitle','off');
imshow(I); hold on;
if ~isempty(K)
    plot(x(K), y(K), 'r', 'LineWidth', 2);
end
title('Polígono convexo sobre la imagen original');

%% 5. Crear máscara poligonal
if ~isempty(K)
    mask_poly = poly2mask(x(K), y(K), size(mar_mask,1), size(mar_mask,2));
else
    mask_poly = false(size(mar_mask));
end

% Mostrar máscara poligonal
figure('Name','Máscara Poligonal','NumberTitle','off');
imshow(mask_poly);
title('Máscara generada a partir del polígono convexo');

%% 6. Aplicar la máscara sobre la imagen original
I_recortada = I;
for c = 1:3
    canal = I(:,:,c);
    canal(~mask_poly) = 0;
    I_recortada(:,:,c) = canal;
end

% Mostrar imagen recortada
figure('Name','Imagen Recortada','NumberTitle','off');
imshow(I_recortada);
title('Imagen recortada con la máscara poligonal');

%% Limpiar
clearvars -except mask_poly I_recortada
