data_folder = 'data/step';
pT_data = cell(10, 1);

for i = 1:10
    filename = sprintf('GeoThermalBox0.01-0.2loopNum%d.mat', i); 
    filepath = fullfile(data_folder, filename);
    mat_data = load(filepath);
    pT_data{i} = mat_data.p.SET.pT; 
end
excel_filename = 'pT_Values.xlsx';

row_numbers = (1:length(pT_data{1}))';
xlswrite(excel_filename, {'Row_Index'}, 1, 'A1');  % A1
xlswrite(excel_filename, row_numbers, 1, 'A2');    % 

for i = 1:10
    col_letter = char('A' + i);
    xlswrite(excel_filename, {sprintf('File_%d', i)}, 1, [col_letter '1']);
    xlswrite(excel_filename, pT_data{i}, 1, [col_letter '2']);
end
