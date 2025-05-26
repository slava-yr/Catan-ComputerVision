clear; close all; clc;

% Cargar imagen
img = imread('imgs2/catan 3.jpeg');
gray = rgb2gray(img);

% Mejorar contraste
gray_adj = imadjust(gray);

% Realzar bordes con Laplaciano
h = fspecial('laplacian', 0.3);
laplacian_filtered = imfilter(gray_adj, h, 'replicate');
laplacian_norm = mat2gray(laplacian_filtered);
enhanced = imadd(gray_adj, uint8(laplacian_norm * 255));

% Suavizado para reducir ruido
img_smooth = imgaussfilt(enhanced, 1.5);

% Binarización adaptativa (Otsu)
level = graythresh(img_smooth);
bw = imbinarize(img_smooth, level);

% Complementar si es necesario
bw = imcomplement(bw);

% Eliminar objetos pequeños (ruido)
bw_clean = bwareaopen(bw, 5000);

% Obtener contornos
[B, ~] = bwboundaries(bw_clean, 'noholes');

% Centro de la imagen
[height, width, ~] = size(img);
center_img = [width/2, height/2];

% Filtrar contornos con área suficientemente grande y calcular distancia al centro
areas = zeros(length(B),1);
dist_centers = zeros(length(B),1);

for k = 1:length(B)
    contour = B{k};
    areas(k) = polyarea(contour(:,2), contour(:,1));
    
    % Centroide del contorno
    cx = mean(contour(:,2));
    cy = mean(contour(:,1));
    
    dist_centers(k) = norm([cx cy] - center_img);
end

% Solo contornos con área > 5000 (puedes ajustar)
idx_big = find(areas > 5000);

% Entre esos, elegir el que está más cerca del centro
[~, idx_min_dist] = min(dist_centers(idx_big));
idx_selected = idx_big(idx_min_dist);

contour_selected = B{idx_selected};

% Simplificar contorno
contour_simplified = reducepoly(contour_selected, 0.01);

% Calcular Convex Hull
k_hull = convhull(contour_selected(:,2), contour_selected(:,1));
hull_x = contour_selected(k_hull,2);
hull_y = contour_selected(k_hull,1);

% Mostrar todos los contornos grandes en azul
figure; imshow(img); hold on;
for k = 1:length(idx_big)
    c = B{idx_big(k)};
    plot(c(:,2), c(:,1), 'b-', 'LineWidth', 1);
end

% Mostrar contorno seleccionado en rojo y polígono simplificado en verde
plot(contour_selected(:,2), contour_selected(:,1), 'r-', 'LineWidth', 2);
plot(contour_simplified(:,2), contour_simplified(:,1), 'g-', 'LineWidth', 2);

% Mostrar convex hull en amarillo
plot(hull_x, hull_y, 'y-', 'LineWidth', 2);

title('Contornos grandes (azul), seleccionado (rojo), simplificado (verde) y Convex Hull (amarillo)');

% Crear máscara con Convex Hull
mask_hull = poly2mask(hull_x, hull_y, height, width);

% Mostrar máscara
figure; imshow(mask_hull);
title('Máscara basada en Convex Hull');
