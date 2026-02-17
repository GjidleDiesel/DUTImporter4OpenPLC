(*
|   Project         : DUTImporter4OpenPLC
|   Version         : 1.0
|   Date            : 2026-02-15
|   FPC Version     : 3.2.2
|   OpenPLC Version : 4.1.2
|   
|   This software is provided "as is", without warranty of any kind, express or implied. 
|   In no event shall the author(s) be held liable for any claim, damages, or other liability arising 
|   from the use of this software.   
|   
|   Disclosure:
|   This progam was made with the help of AI. I am a smooth brain PLC programmer who
|   wanted this tool, fast. Which is why i spent days on this, rather than manually adding my
|   my DUTs...
|   Hope the tool is of more use to you than me.
|   
|   Usage:
|   ./DUTImporter4OpenPLC "/home/user/Documents/example types/" "/home/user/Documents/example project/project.json"
*)


program DUTIImporter4OpenPLC;

{$mode objfpc}
{$H+}

uses
  Classes,
  SysUtils,
  StrUtils,
  fpjson,
  jsonparser;



function StripComment(const Line: string): string;
var
  p1, p2: SizeInt;
begin
  Result := Line;
  p1 := Pos('(*', Result);
  while p1 > 0 do
  begin
    p2 := Pos('*)', Result);
    if p2 > p1 then
      Delete(Result, p1, p2 - p1 + 2)
    else
      Delete(Result, p1, Length(Result));
    p1 := Pos('(*', Result);
  end;
end;



function IsBaseType(const T: string): Boolean;
var
  L: string;
begin
  L := LowerCase(T);
  Result :=
    (L = 'real') or
    (L = 'bool') or
    (L = 'int') or
    (L = 'dint') or
    (L = 'word') or
    (L = 'dword') or
    (Pos('string', L) = 1);
end;



function MapType(const PlcType: string): string;
begin
  if Pos('string', LowerCase(PlcType)) = 1 then
    Exit('string');
  Result := LowerCase(PlcType);
end;



function CreateUserTypeJSON(const Name, TypeName: string): TJSONObject;
var
  VarObj, TypeObj: TJSONObject;
begin
  VarObj := TJSONObject.Create;
  VarObj.Add('name', Name);

  TypeObj := TJSONObject.Create;
  TypeObj.Add('definition', 'user-data-type');
  TypeObj.Add('value', TypeName);

  VarObj.Add('type', TypeObj);
  Result := VarObj;
end;



function CreateArrayJSON(const Name, FullType: string): TJSONObject;
var
  VarObj, TypeObj, DataObj, BaseTypeObj: TJSONObject;
  DimArray: TJSONArray;
  UpperType: string;
  OfPos: Integer;
  BaseTypeStr: string;
  StartPos, EndPos: Integer;
  DimContent: string;
  DimList: TStringList;
  i: Integer;
  DimObj: TJSONObject;
begin
  VarObj := TJSONObject.Create;
  VarObj.Add('name', Name);

  TypeObj := TJSONObject.Create;
  TypeObj.Add('definition', 'array');
  TypeObj.Add('value', Trim(FullType));

  DataObj := TJSONObject.Create;
  BaseTypeObj := TJSONObject.Create;
  DimArray := TJSONArray.Create;

  UpperType := UpperCase(FullType);

  OfPos := Pos('OF', UpperType);

  if OfPos > 0 then
    BaseTypeStr := Trim(Copy(FullType, OfPos + 2, Length(FullType)))
  else
    BaseTypeStr := '';

  if BaseTypeStr <> '' then
  begin
    if IsBaseType(BaseTypeStr) then
    begin
      BaseTypeObj.Add('definition', 'base-type');
      BaseTypeObj.Add('value', MapType(BaseTypeStr));
    end
    else
    begin
      BaseTypeObj.Add('definition', 'user-data-type');
      BaseTypeObj.Add('value', BaseTypeStr);
    end;
  end
  else
  begin
    BaseTypeObj.Add('definition', 'base-type');
    BaseTypeObj.Add('value', 'unknown');
  end;

  DataObj.Add('baseType', BaseTypeObj);

  StartPos := 1;

  while True do
  begin
    StartPos := PosEx('[', FullType, StartPos);
    if StartPos = 0 then Break;

    EndPos := PosEx(']', FullType, StartPos);
    if EndPos = 0 then Break;

    DimContent := Copy(FullType, StartPos + 1, EndPos - StartPos - 1);

    DimList := TStringList.Create;
    DimList.StrictDelimiter := True;
    DimList.Delimiter := ',';
    DimList.DelimitedText := DimContent;

    for i := 0 to DimList.Count - 1 do
    begin
      DimObj := TJSONObject.Create;
      DimObj.Add('dimension', Trim(DimList[i]));
      DimArray.Add(DimObj);
    end;

    DimList.Free;

    StartPos := EndPos + 1;
  end;

  DataObj.Add('dimensions', DimArray);
  TypeObj.Add('data', DataObj);
  VarObj.Add('type', TypeObj);

  Result := VarObj;
end;



function CreateVariableJSON(const Name, PlcType: string): TJSONObject;
begin
  if Pos('ARRAY', UpperCase(PlcType)) = 1 then
    Exit(CreateArrayJSON(Name, PlcType));

  if IsBaseType(PlcType) then
  begin
    Result := TJSONObject.Create;
    Result.Add('name', Name);

    Result.Add('type', TJSONObject.Create);
    Result.Objects['type'].Add('definition', 'base-type');
    Result.Objects['type'].Add('value', MapType(PlcType));
  end
  else
    Result := CreateUserTypeJSON(Name, PlcType);
end;



function ParseEnum(const Lines: TStringList; StartIndex: Integer; const TypeName: string): TJSONObject;
var
  EnumObj, ValueObj: TJSONObject;
  ValuesArray: TJSONArray;
  Line, CleanLine, DefaultValue: string;
  AssignPos, i: Integer;
begin
  EnumObj := TJSONObject.Create;
  EnumObj.Add('name', TypeName);
  EnumObj.Add('derivation', 'enumerated');

  ValuesArray := TJSONArray.Create;
  DefaultValue := '';

  for i := StartIndex to Lines.Count - 1 do
  begin
    Line := Trim(StripComment(Lines[i]));
    if Pos(')', Line) > 0 then
    begin
      AssignPos := Pos(':=', Line);
      if AssignPos > 0 then
      begin
        DefaultValue := Trim(Copy(Line, AssignPos + 2, Length(Line)));
        DefaultValue := StringReplace(DefaultValue, ';', '', []);
      end;
      Break;
    end;

    if Line <> '' then
    begin
      if Line[Length(Line)] = ',' then Delete(Line, Length(Line), 1);
      AssignPos := Pos(':=', Line);
      if AssignPos > 0 then CleanLine := Trim(Copy(Line, 1, AssignPos - 1))
      else CleanLine := Line;

      ValueObj := TJSONObject.Create;
      ValueObj.Add('description', CleanLine);
      ValuesArray.Add(ValueObj);
    end;
  end;

  EnumObj.Add('values', ValuesArray);
  if DefaultValue <> '' then EnumObj.Add('initialValue', DefaultValue);

  Result := EnumObj;
end;



function ParseStruct(const Lines: TStringList; StartIndex: Integer; const TypeName: string): TJSONObject;
var
  i, ColonPos, SemiPos: Integer;
  Line, NamePart, TypePart: string;
  VarArray: TJSONArray;
begin
  VarArray := TJSONArray.Create;

  i := StartIndex;
  while i < Lines.Count do
  begin
    Line := Trim(StripComment(Lines[i]));
    Inc(i);
    if Line = '' then Continue;
    if Pos('END_STRUCT', UpperCase(Line)) > 0 then Break;

    SemiPos := Pos(';', Line);
    if SemiPos = 0 then Continue;

    Line := Copy(Line, 1, SemiPos - 1);
    ColonPos := Pos(':', Line);
    if ColonPos = 0 then Continue;

    NamePart := Trim(Copy(Line, 1, ColonPos - 1));
    TypePart := Trim(Copy(Line, ColonPos + 1, Length(Line)));

    if Pos('ARRAY', UpperCase(TypePart)) = 1 then
      VarArray.Add(CreateArrayJSON(NamePart, TypePart))
    else
      VarArray.Add(CreateVariableJSON(NamePart, TypePart));
  end;

  Result := TJSONObject.Create;
  Result.Add('name', TypeName);
  Result.Add('derivation', 'structure');
  Result.Add('variable', VarArray);
end;



function ParseType(const FileName: string): TJSONObject;
var
  Lines: TStringList;
  i: Integer;
  Line, TypeName: string;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    TypeName := '';

    for i := 0 to Lines.Count - 1 do
    begin
      Line := Trim(StripComment(Lines[i]));
      if Line = '' then Continue;

      if Pos('TYPE', UpperCase(Line)) = 1 then
      begin
        if Pos(':', Line) > 0 then TypeName := Trim(Copy(Line, 5, Pos(':', Line) - 5));
        Continue;
      end;

      if Pos('STRUCT', UpperCase(Line)) > 0 then
      begin
        Result := ParseStruct(Lines, i + 1, TypeName);
        Exit;
      end;

      if (Length(Line) > 0) and (Line[1] = '(') then
      begin
        Result := ParseEnum(Lines, i + 1, TypeName);
        Exit;
      end;
    end;

    raise Exception.Create('No valid TYPE definition found in file: ' + FileName);

  finally
    Lines.Free;
  end;
end;



procedure PatchProject(const TypeObj: TJSONObject; const ProjectFile: string);
var
  Root, DataObj: TJSONObject;
  DataTypes: TJSONArray;
  Dummy: TJSONData;
  Existing: TJSONObject;
  Parser: TJSONParser;
  FileStream: TFileStream;
  JsonStr: string;
  TypeName: string;
  i: Integer;
begin
  FileStream := TFileStream.Create(ProjectFile, fmOpenRead);
  try
    Parser := TJSONParser.Create(FileStream, []);
    try
      Root := Parser.Parse as TJSONObject;
    finally
      Parser.Free;
    end;
  finally
    FileStream.Free;
  end;

  if Root = nil then
    raise Exception.Create('Invalid project.json (root invalid)');

  if not Root.Find('data', Dummy) then
    raise Exception.Create('Invalid project.json (missing "data")');

  DataObj := Dummy as TJSONObject;

  if not DataObj.Find('dataTypes', Dummy) then
    raise Exception.Create('Invalid project.json (missing "dataTypes")');

  DataTypes := Dummy as TJSONArray;

  if not DataObj.Find('configuration', Dummy) then
    raise Exception.Create('Invalid project.json (missing "configuration")');

  TypeName := TypeObj.Strings['name'];

  for i := DataTypes.Count - 1 downto 0 do
  begin
    Existing := DataTypes.Objects[i];
    if Existing.Strings['name'] = TypeName then
      DataTypes.Delete(i);
  end;

  DataTypes.Add(TypeObj.Clone);
  TypeObj.Free;

  JsonStr := Root.FormatJSON;

  FileStream := TFileStream.Create(ProjectFile, fmCreate);
  try
    FileStream.WriteBuffer(Pointer(JsonStr)^, Length(JsonStr));
  finally
    FileStream.Free;
  end;

  Root.Free;
end;



procedure ProcessFolder(const FolderPath, ProjectFile: string);
var
  SR: TSearchRec;
  FullPath, Ext: string;
  TypeObj: TJSONObject;
begin
  if FindFirst(IncludeTrailingPathDelimiter(FolderPath) + '*.*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        Ext := LowerCase(ExtractFileExt(SR.Name));
        if (Ext = '.st') or (Ext = '.txt') then
        begin
          FullPath := IncludeTrailingPathDelimiter(FolderPath) + SR.Name;
          WriteLn('Parsing: ', FullPath);

          try
            TypeObj := ParseType(FullPath);
            PatchProject(TypeObj, ProjectFile);
            WriteLn('  -> Imported successfully');
          except
            on E: Exception do WriteLn('  -> Error: ', E.Message);
          end;
        end;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end
  else
    WriteLn('No .st or .txt files found in folder.');
end;





(*____________________________________________MAIN__________________________________________*)

var
  DUTPath, ProjectFile: string;
  Answer: string;
  TypeObj: TJSONObject;
begin
  if ParamCount <> 2 then
  begin
    WriteLn('Usage: DUTImport4OpenPLC <DUTFile.st | FolderPath> <project.json>');
    Halt(1);
  end;

  DUTPath := ExpandFileName(ParamStr(1));
  ProjectFile := ExpandFileName(ParamStr(2));

  if not FileExists(ProjectFile) then
  begin
    WriteLn('Error: Project file not found:');
    WriteLn('  ', ProjectFile);
    Halt(1);
  end;

  if LowerCase(ExtractFileName(ProjectFile)) <> 'project.json' then
  begin
    WriteLn('Warning: The selected file is not named "project.json".');
    WriteLn('Proceeding anyway...');
  end;

  if not DirectoryExists(DUTPath) then
  begin
    if not FileExists(DUTPath) then
    begin
      WriteLn('Error: DUT file or folder not found: ', DUTPath);
      Halt(1);
    end;

    if not ((LowerCase(ExtractFileExt(DUTPath)) = '.st') or
            (LowerCase(ExtractFileExt(DUTPath)) = '.txt')) then
    begin
      WriteLn('Error: Unsupported file type. Only .st and .txt are allowed.');
      Halt(1);
    end;
  end;

  WriteLn('Source path   : ', DUTPath);
  WriteLn('Project file  : ', ProjectFile);
  WriteLn;
  WriteLn('WARNING: Make sure you have made a backup of your OpenPLC project!');
  Write('Do you want to proceed? (y/N): ');
  ReadLn(Answer);

  Answer := LowerCase(Trim(Answer));
  if (Answer <> 'y') and (Answer <> 'yes') then
  begin
    WriteLn('Operation cancelled.');
    Halt(0);
  end;

  try
    if DirectoryExists(DUTPath) then
    begin
      ProcessFolder(DUTPath, ProjectFile);
      WriteLn('Folder import complete.');
    end
    else
    begin
      TypeObj := ParseType(DUTPath);
      PatchProject(TypeObj, ProjectFile);
      WriteLn('Type successfully imported to project.json');
    end;
  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.Message);
      Halt(1);
    end;
  end;
end.







