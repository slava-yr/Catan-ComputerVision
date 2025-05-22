clc; clear; close all;

%% --- 1: Cargar imagen ---
img = imread('hola.png');
[h, w, ~] = size(img);

% Mostrar la imagen original una vez
figure('Name', 'Imagen Original');
imshow(img); title('Imagen Original');

%% --- Parámetros del filtro bilateral a comparar ---
bilateral_params = [
    0.1, 2;
    0.2, 3;
    0.4, 4;
    0.6, 5
];
num_variantes = size(bilateral_params, 1);

k = 7;  % Número de clusters para k-means
umbral_area_min = 1500;
se = strel('disk', 5);

% Figura para comparación
figure('Name', 'Comparación de preprocesamientos', 'Position', [100, 100, 1200, 800]);

for idx = 1:num_variantes
    smooth = bilateral_params(idx, 1);
    sigma = bilateral_params(idx, 2);

    % --- Preprocesamiento ---
    img_bilateral = imbilatfilt(img, smooth, sigma);

    % --- Segmentación ---
    ycbcr_img = rgb2ycbcr(img_bilateral);
    ycbcr_img_single = im2single(ycbcr_img);
    L_ycbcr = imsegkmeans(ycbcr_img_single, k);

    % --- Filtrado de clusters ---
    L_filtrado = zeros(size(L_ycbcr), 'like', L_ycbcr);
    for i = 1:k
        mask_i = (L_ycbcr == i);
        mask_i = bwareaopen(mask_i, umbral_area_min);
        mask_i = imdilate(mask_i, se);
        mask_i = imclose(mask_i, se);
        mask_i = imerode(mask_i, se);
        L_filtrado(mask_i) = i;
    end

    % --- Rellenar losetas ---
    L_rellenado = zeros(size(L_filtrado), 'like', L_filtrado);
    for i = 1:k
        mask_i = (L_filtrado == i);
        mask_i_relleno = imfill(mask_i, 'holes');
        L_rellenado(mask_i_relleno) = i;
    end

    % --- Métricas de calidad ---
    props = regionprops(L_rellenado, 'Area', 'Perimeter');
    areas = [props.Area];
    perimeters = [props.Perimeter];
    compacidad = (4 * pi .* areas) ./ (perimeters.^2);
    
    n_losetas = numel(areas);
    area_prom = mean(areas);
    comp_prom = mean(compacidad);

    % --- Mostrar en figura ---
    subplot(num_variantes, 2, (idx - 1) * 2 + 1);
    imshow(img_bilateral);
    title(sprintf('Bilateral %.1f / %.1f', smooth, sigma));

    subplot(num_variantes, 2, (idx - 1) * 2 + 2);
    imshow(label2rgb(L_rellenado, 'jet', 'k'));
    title(sprintf('N: %d | A: %.0f | C: %.2f', ...
        n_losetas, area_prom, comp_prom));
end
