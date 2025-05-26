clear; close all; clc;

% Cargar imagen
img = imread('imgs2/catan 3.jpeg');
gray = rgb2gray(img);
gray_adj = imadjust(gray);

% Filtro Laplaciano para realce de bordes
h = fspecial('laplacian', 0.3);
laplacian_filtered = imfilter(gray_adj, h, 'replicate');
laplacian_norm = mat2gray(laplacian_filtered);
enhanced = imadd(gray_adj, uint8(laplacian_norm * 255));

% Suavizado Gaussiano
sigma_gauss = 1.5;
img_smooth = imgaussfilt(enhanced, sigma_gauss);

% Detectar bordes Canny con umbral [0.1 0.3]
edges = edge(img_smooth, 'canny', [0.1 0.3]);

% Dilatación ligera (disco radio 1)
se = strel('disk', 1);
edges_dilated = imdilate(edges, se);

% Transformada de Hough
[H, theta, rho] = hough(edges_dilated);
P = houghpeaks(H, 20, 'Threshold', ceil(0.3 * max(H(:))));
lines = houghlines(edges_dilated, theta, rho, P, 'FillGap', 20, 'MinLength', 100);

% Tamaño de la imagen
[height, width, ~] = size(img);
cx = width / 2;
cy = height / 2;

%% Visualizar todas las líneas detectadas por Hough
figure, imshow(img), hold on, title('Todas las líneas detectadas por Hough');
for k = 1:length(lines)
    x = [lines(k).point1(1), lines(k).point2(1)];
    y = [lines(k).point1(2), lines(k).point2(2)];
    plot(x, y, 'b-', 'LineWidth', 2);
end
hold off;

%% Filtrar líneas por ángulo
valid_angles = [-60, 0, 60]; % grados
tolerance = 10; % margen en grados

% Estructura para almacenar grupos de líneas por orientación
groups = struct('angle', {}, 'lines', {});

for i = 1:length(valid_angles)
    groups(i).angle = valid_angles(i);
    groups(i).lines = [];
end

for k = 1:length(lines)
    dx = lines(k).point2(1) - lines(k).point1(1);
    dy = lines(k).point2(2) - lines(k).point1(2);
    angle = atan2d(dy, dx); % [-180, 180]

    % Normalizar a [-90, 90]
    angle = mod(angle + 180, 180);
    if angle > 90
        angle = angle - 180;
    end

    % Buscar grupo más cercano por ángulo
    diffs = abs(angle - valid_angles);
    [min_diff, idx] = min(diffs);

    if min_diff < tolerance
        if isempty(groups(idx).lines)
            groups(idx).lines = lines(k);
        else
            groups(idx).lines(end+1) = lines(k);
        end
    end
end

% Seleccionar las 2 líneas más largas por grupo
selected_lines = [];

for i = 1:length(groups)
    lines_group = groups(i).lines;
    if isempty(lines_group)
        continue
    end

    % Calcular longitud de cada línea
    lengths = zeros(1, length(lines_group));
    for j = 1:length(lines_group)
        x1 = lines_group(j).point1(1);
        y1 = lines_group(j).point1(2);
        x2 = lines_group(j).point2(1);
        y2 = lines_group(j).point2(2);
        lengths(j) = sqrt((x2 - x1)^2 + (y2 - y1)^2);
    end

    % Ordenar por longitud descendente
    [~, idx_sorted] = sort(lengths, 'descend');

    % Tomar hasta 2 líneas más largas
    n_take = min(2, length(idx_sorted));
    selected_lines = [selected_lines, lines_group(idx_sorted(1:n_take))];
end

%% Visualizar líneas seleccionadas y extendidas
figure, imshow(img), title('Líneas seleccionadas por orientación y longitud (extendidas)');
hold on;

% Dibujar líneas de referencia para orientación
len = min(height, width);
angles_ref = [0, 60, -60];
colors_ref = {'m--', 'c--', 'y--'};

for i = 1:length(angles_ref)
    ang = deg2rad(angles_ref(i));
    dx = cos(ang) * len/2;
    dy = sin(ang) * len/2;
    x1 = cx - dx; x2 = cx + dx;
    y1 = cy - dy; y2 = cy + dy;
    plot([x1, x2], [y1, y2], colors_ref{i}, 'LineWidth', 1.5);
end

% Dibujar líneas seleccionadas
for k = 1:length(selected_lines)
    x = [selected_lines(k).point1(1), selected_lines(k).point2(1)];
    y = [selected_lines(k).point1(2), selected_lines(k).point2(2)];

    % Línea original (verde)
    plot(x, y, 'g-', 'LineWidth', 2);

    % Ajustar recta y = mx + b
    p = polyfit(x, y, 1);

    % Intersección con bordes verticales
    y1 = p(1)*1 + p(2);
    y2 = p(1)*width + p(2);

    % Intersección con bordes horizontales
    if abs(p(1)) > 1e-5
        x1 = (1 - p(2))/p(1);
        x2 = (height - p(2))/p(1);
    else
        x1 = Inf;
        x2 = Inf;
    end

    % Recolectar puntos válidos
    pts = [];
    if y1 >= 1 && y1 <= height
        pts = [pts; 1, y1];
    end
    if y2 >= 1 && y2 <= height
        pts = [pts; width, y2];
    end
    if x1 >= 1 && x1 <= width
        pts = [pts; x1, 1];
    end
    if x2 >= 1 && x2 <= width
        pts = [pts; x2, height];
    end

    % Dibujar línea extendida (roja)
    if size(pts,1) >= 2
        plot(pts(:,1), pts(:,2), 'r-', 'LineWidth', 2);
    end
end

hold off;
