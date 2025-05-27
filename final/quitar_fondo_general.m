clear; close all; clc;

% Crear figuras para cada etapa
fig_orig = figure('Name','Imágenes Originales','NumberTitle','off');
fig_contornos = figure('Name','Contornos Convexos','NumberTitle','off');
fig_mascaras = figure('Name','Máscaras de Recorte','NumberTitle','off');
fig_sinfondo = figure('Name','Imagen sin Fondo','NumberTitle','off');

for i = 1:10
    I = imread(sprintf('imgs2/catan %d.jpeg', i));
    hsv = rgb2hsv(I);

    % Mostrar imagen original SIN NADA
    figure(fig_orig);
    subplot(2,5,i);
    imshow(I);
    title(sprintf('Original %d', i));

    % Máscara de mar basada en HSV
    mar_mask = (hsv(:,:,1)>0.5 & hsv(:,:,1)<0.7) & (hsv(:,:,2)>0.4) & (hsv(:,:,3)>0.3);
    mar_mask = imclose(imopen(mar_mask, strel('disk',5)), strel('disk',10));
    mar_mask = imfill(mar_mask,'holes');

    % Región más grande
    CC = bwconncomp(mar_mask);
    numPixels = cellfun(@numel, CC.PixelIdxList);
    mask_largest = false(size(mar_mask));
    if ~isempty(numPixels)
        mask_largest(CC.PixelIdxList{numPixels == max(numPixels)}) = true;
    end

    % Perímetro y contorno convexo
    [y,x] = find(bwperim(mask_largest));
    if numel(x) >= 3
        K = convhull(x, y);
    else
        K = [];
    end

    % Máscara poligonal
    if ~isempty(K)
        mask_poly = poly2mask(x(K), y(K), size(mar_mask,1), size(mar_mask,2));
    else
        mask_poly = false(size(mar_mask));
    end

    % Mostrar imagen con contorno (sobre imagen original)
    figure(fig_contornos);
    subplot(2,5,i);
    imshow(I); hold on;
    if ~isempty(K)
        plot(x(K), y(K), 'r', 'LineWidth', 2);
    end
    hold off;
    title(sprintf('Contorno %d', i));

    % Mostrar máscara binaria
    figure(fig_mascaras);
    subplot(2,5,i);
    imshow(mask_poly);
    title(sprintf('Máscara %d', i));

    % Imagen recortada (sin fondo)
    img_sin_fondo = I;
    for c = 1:3
        canal = I(:,:,c);
        canal(~mask_poly) = 0;
        img_sin_fondo(:,:,c) = canal;
    end

    figure(fig_sinfondo);
    subplot(2,5,i);
    imshow(img_sin_fondo);
    title(sprintf('Sin fondo %d', i));
end
