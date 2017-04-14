unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Grids, ComCtrls,WinInet,shellapi;

type
  TPlayer = Record
    lastchecked:TDateTime;
    SteamId,NumberOfVACBans,DaysSinceLastBan,NumberOfGameBans,EconomyBan,CommunityBanned,VACBanned:String;
    MatchName,FileDate:String;
    playedMatches:Integer;
    demoDate:Integer;
  end;

type
  TServer = Record
    Player: Array of String;
    Server,Client,ProtVer,NetVer,Map,Time:String;
    demoDate:Integer;
  end;

type
  { TFormMain }
  TFormMain = class(TForm)
    ButtonCheckAndSort: TButton;
    ButtonApiKey: TButton;
    ButtonDir: TButton;
    ButtonList: TButton;
    EditPath: TEdit;
    LabelProgress: TLabel;
    LabelProgressPlayer: TLabel;
    ListBox: TListBox;
    ProgressBar: TProgressBar;
    SelectDirectoryDialog: TSelectDirectoryDialog;
    StringGrid: TStringGrid;
    procedure ButtonApiKeyClick(Sender: TObject);
    procedure ButtonCheckAndSortClick(Sender: TObject);
    procedure ButtonDirClick(Sender: TObject);
    procedure ButtonListClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure StringGridMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure StringGridMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    Playerlist:Array of TPlayer;
    MainDirectory:String;
    myFile    : File;
    myArray   : Array of Byte;
    iFileSize: Integer;
    Server:TServer;
    apikey: String;
    procedure AddPlayerToList(var PlayerURL,FileName:String;var demoDate:Integer);
    procedure GetPlayers(var Filepath,FileName:String);
    procedure FindID;
    function Compare(i:Integer):Boolean;
    function GetArrayString(Index,Size:Integer):String;
    procedure SortPlayerVac;
    procedure SwitchPlayer(Index:Integer);
    { private declarations }
  public
    { public declarations }
  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

{ TFormMain }

procedure TFormMain.FormCreate(Sender: TObject);
var
  replayfolder:TStringList;
begin
  MainDirectory:=getcurrentdir;
  if FileExists(MainDirectory+'replayfolder.txt') then
  begin
    replayfolder:=TStringList.Create;
    replayfolder.LoadFromFile(MainDirectory+'replayfolder.txt');
    EditPath.Text:=replayfolder[0];
    replayfolder.free;
  end;
end;

procedure TFormMain.StringGridMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin

end;

procedure TFormMain.StringGridMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  s:String;
begin
  s:='';
  if StringGrid.Row>0 then
  if length(Playerlist)-1 >= StringGrid.Row-1 then
    s:=Playerlist[StringGrid.Row-1].SteamId;
  if s<>'' then
  begin
    s:='http://steamcommunity.com/profiles/'+s;
    ShellExecute(0, 'OPEN', PChar(s), '', '', 1);    //SW_SHOWNORMAL=1
  end;
end;

function GetUrlContent(const Url: string): string;
var
  NetHandle: HINTERNET;
  UrlHandle: HINTERNET;
  Buffer: array[0..1024] of Char;
  BytesRead: dWord;
begin
  Result := '';
  NetHandle := InternetOpen('Lazarus', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if Assigned(NetHandle) then
  begin
    UrlHandle := InternetOpenUrl(NetHandle, PChar(Url), nil, 0, INTERNET_FLAG_RELOAD, 0);
    if Assigned(UrlHandle) then
    begin
      FillChar(Buffer, SizeOf(Buffer), 0);
      repeat
        Result := Result + Buffer;
        FillChar(Buffer, SizeOf(Buffer), 0);
        BytesRead:=0;
        InternetReadFile(UrlHandle, @Buffer, SizeOf(Buffer), BytesRead);
      until BytesRead = 0;
      InternetCloseHandle(UrlHandle);
    end
    else
      raise Exception.CreateFmt('Cannot open URL %s', [Url]);
    InternetCloseHandle(NetHandle);
  end
  else
    raise Exception.Create('Error initialize Wininet');
end;

function  compareString(SourceString,TargetString:String):Boolean;
var
  i : Integer;
begin
  Result:=True;
  for i := 1 to length(TargetString) do
    if SourceString[i]<>TargetString[i] then
      Result:=False;
end;

procedure findStringNew(var SourceString:String;var TargetPlayer:TPlayer;min,max:Integer);
var
  sl:TStringlist;
  s:String;
  i:Integer;
begin
  sl:=TStringlist.Create;
  s:='';
  for i := min to max do
  begin
    if SourceString[i] = ',' then
    begin
      sl.Add(s);
      s:='';
    end
    else
    if (Ord(SourceString[i]) > 47) and (Ord(SourceString[i]) < 123) then
      s:=s+SourceString[i];
  end;

  for i := 0 to sl.Count-1 do
  begin
    if compareString(sl[i],'SteamId') then
    begin
      s:=sl[i];
      Delete(s,1,length('SteamId')+1);
      TargetPlayer.SteamId:=s;
    end;

    if compareString(sl[i],'CommunityBanned') then
    begin
      s:=sl[i];
      Delete(s,1,length('CommunityBanned')+1);
      TargetPlayer.CommunityBanned:=s;
    end;

    if compareString(sl[i],'VACBanned') then
    begin
      s:=sl[i];
      Delete(s,1,length('VACBanned')+1);
      TargetPlayer.VACBanned:=s;
    end;

    if compareString(sl[i],'NumberOfVACBans') then
    begin
      s:=sl[i];
      Delete(s,1,length('NumberOfVACBans')+1);
      TargetPlayer.NumberOfVACBans:=s;
    end;

    if compareString(sl[i],'DaysSinceLastBan') then
    begin
      s:=sl[i];
      Delete(s,1,length('DaysSinceLastBan')+1);
      TargetPlayer.DaysSinceLastBan:=s;
    end;

    if compareString(sl[i],'NumberOfGameBans') then
    begin
      s:=sl[i];
      Delete(s,1,length('NumberOfGameBans')+1);
      TargetPlayer.NumberOfGameBans:=s;
    end;

    if compareString(sl[i],'EconomyBan') then
    begin
      s:=sl[i];
      Delete(s,1,length('EconomyBan')+1);
      TargetPlayer.EconomyBan:=s;
    end;
  end;

  if (TargetPlayer.NumberOfGameBans = '0') and (TargetPlayer.NumberOfVACBans = '0') then
    TargetPlayer.DaysSinceLastBan:='';

  TargetPlayer.lastchecked:=now;
end;

procedure parseSteamApi(var SourceString:String;var TargetPlayer:TPlayer);
var
  i,min,max:Integer;
begin
  min:=0;
  max:=0;
  i:=2;
  while (i < length(SourceString)) and (max = 0) do
  begin
    if Ord(SourceString[i]) = 123 then
      min:=i;
    if Ord(SourceString[i]) = 125 then
      max:=i;
    inc(i);
  end;
  if min>max then
    exit;
  findStringNew(SourceString,TargetPlayer,min,max);
end;

function stringmatch(Source,Target:String;Index:Integer):Boolean;
var
  i:Integer;
begin
  Result:=True;
  for i := 1 to length(Target)-1 do
    if Source[Index+i-1]<>Target[i] then
    begin
      Result:=False;
      exit;
    end;
end;

function findVacString(Source,Target:String):String;
var
  bMatch,bStart:Boolean;
  i:Integer;
begin
  Result := '' ;
  bMatch:=False;
  bStart:=False;
  for i := 1 to length(Source)-1 do
  begin
    if bstart and (Source[i+1] = '<') then
    begin
      bMatch := False;
      bStart := False;
    end;
    if bMatch and bStart then
      if (Ord(Source[i]) > 47) and (Ord(Source[i]) < 58) then
        Result := Result+Source[i];
    if stringmatch(Source,Target,i) then
      bMatch := True;
    if Source[i]+Source[i+1] = 'v>' then
      bStart := True;
  end;
end;

procedure TFormMain.SwitchPlayer(Index:Integer);
var
  s:String;
  td:TDateTime;
  i:Integer;
begin
    s:=Playerlist[Index].SteamId;
    Playerlist[Index].SteamId:=Playerlist[Index+1].SteamId;
    Playerlist[Index+1].SteamId:=s;

    s:=Playerlist[Index].NumberOfVACBans;
    Playerlist[Index].NumberOfVACBans:=Playerlist[Index+1].NumberOfVACBans;
    Playerlist[Index+1].NumberOfVACBans:=s;

    s:=Playerlist[Index].DaysSinceLastBan;
    Playerlist[Index].DaysSinceLastBan:=Playerlist[Index+1].DaysSinceLastBan;
    Playerlist[Index+1].DaysSinceLastBan:=s;

    s:=Playerlist[Index].NumberOfGameBans;
    Playerlist[Index].NumberOfGameBans:=Playerlist[Index+1].NumberOfGameBans;
    Playerlist[Index+1].NumberOfGameBans:=s;

    s:=Playerlist[Index].EconomyBan;
    Playerlist[Index].EconomyBan:=Playerlist[Index+1].EconomyBan;
    Playerlist[Index+1].EconomyBan:=s;

    s:=Playerlist[Index].CommunityBanned;
    Playerlist[Index].CommunityBanned:=Playerlist[Index+1].CommunityBanned;
    Playerlist[Index+1].CommunityBanned:=s;

    s:=Playerlist[Index].VACBanned;
    Playerlist[Index].VACBanned:=Playerlist[Index+1].VACBanned;
    Playerlist[Index+1].VACBanned:=s;

    s:=Playerlist[Index].MatchName;
    Playerlist[Index].MatchName:=Playerlist[Index+1].MatchName;
    Playerlist[Index+1].MatchName:=s;

    s:=Playerlist[Index].FileDate;
    Playerlist[Index].FileDate:=Playerlist[Index+1].FileDate;
    Playerlist[Index+1].FileDate:=s;

    td:=Playerlist[Index].lastchecked;
    Playerlist[Index].lastchecked:=Playerlist[Index+1].lastchecked;
    Playerlist[Index+1].lastchecked:=td;

    i:=Playerlist[Index].demoDate;
    Playerlist[Index].demoDate:=Playerlist[Index+1].demoDate;
    Playerlist[Index+1].demoDate:=i;
end;

procedure TFormMain.SortPlayerVac;
var
  bSwitch,bRound:Boolean;
  i:Integer;
begin
  bSwitch:=True;
  while bSwitch do
  begin
    bRound:=True;
    for i := 0 to length(Playerlist)-2 do
    if Playerlist[i+1].DaysSinceLastBan <> ''  then
      if Playerlist[i].DaysSinceLastBan <> '' then
      begin
        if StrToInt(Playerlist[i+1].DaysSinceLastBan) < StrToInt(Playerlist[i].DaysSinceLastBan) then
        begin
          SwitchPlayer(i);
          bRound:=False;
        end;
      end
      else
      begin
        SwitchPlayer(i);
        bRound:=False;
      end;
      if bRound then
      bSwitch:=False;
  end;
end;

procedure TFormMain.ButtonCheckAndSortClick(Sender: TObject);
var
  s:String;
  i,maxsteps:Integer;
  stepsize,currstep:Double;
  apifile: TStringList;
begin
//check
  ProgressBar.Position:=0;
  Application.ProcessMessages;
  ButtonCheckAndSort.Enabled:=False;
  currstep:=0;
  maxsteps:=length(Playerlist);
  if FileExists(MainDirectory+'apikey.txt') then
  begin
    apifile:=TStringList.Create;
    apifile.LoadFromFile(MainDirectory+'apikey.txt');
    apikey:=apifile[0];
    apifile.free;
  end;
  if apikey = '' then
  begin
    showmessage('please add an api key');
    exit;
  end;

  if maxsteps>0 then
  begin
    stepsize:=100/maxsteps;
    for i := 0 to maxsteps-1 do
    begin
      Application.ProcessMessages;
      LabelProgressPlayer.Caption:=IntToStr(i+1)+'/'+IntToStr(maxsteps)+ ' players checked';
      currstep:=currstep+stepsize;
      ProgressBar.Position:=Round(currstep);
      s:=GetUrlContent('http://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key='+apikey+'&steamids='+Playerlist[i].SteamId);
      parseSteamApi(s,Playerlist[i]);
      //s:=GetUrlContent('http://steamcommunity.com/profiles/'+Playerlist[i].URL);
      //Playerlist[i].Name:=FindString(s,'<div class="persona_name" style="font-size:');
      //Playerlist[i].Vac:=FindString(s,'<div class="profile_ban">');
      //Playerlist[i].VacTime:=FindVacString(s,'<a class="whiteLink" href="http://steamcommunity.com/actions/WhatIsVAC">');
      //sleep(10);
      s:='';
    end;
    ButtonCheckAndSort.Enabled:=True;
  end;
//sort
  SortPlayerVac;
//show
  StringGrid.RowCount:=length(Playerlist)+1;
  StringGrid.ColCount:=9;
  StringGrid.Cells[8,0]:='FileDate';
  StringGrid.Cells[7,0]:='DemoName';
  StringGrid.Cells[6,0]:='LastChecked';
  StringGrid.Cells[5,0]:='-';
  //StringGrid.Cells[5,0]:='PlayerName';
  StringGrid.Cells[4,0]:='Gameban';
  StringGrid.Cells[3,0]:='VAC';
  StringGrid.Cells[2,0]:='Ban since';
  StringGrid.Cells[1,0]:='SteamId';
  for i := 0 to length(Playerlist)-1 do
  begin
    StringGrid.Cells[0,i+1]:=IntToSTr(i+1);
    StringGrid.Cells[1,i+1]:=Playerlist[i].SteamId;
    StringGrid.Cells[2,i+1]:=Playerlist[i].DaysSinceLastBan;
    StringGrid.Cells[3,i+1]:=Playerlist[i].VACBanned;
    StringGrid.Cells[4,i+1]:=Playerlist[i].NumberOfGameBans;
    //StringGrid.Cells[4,i+1]:=Playerlist[i].URL;
    StringGrid.Cells[6,i+1]:=DateTimeToStr(Playerlist[i].lastchecked);
    StringGrid.Cells[7,i+1]:=Playerlist[i].MatchName;
    StringGrid.Cells[8,i+1]:=DateToStr(FileDateToDateTime(Playerlist[i].demoDate));
  end
end;

procedure TFormMain.ButtonApiKeyClick(Sender: TObject);
var
  apifile: TStringList;
begin
  if FileExists(MainDirectory+'apikey.txt') then
  begin
    apifile:=TStringList.Create;
    apifile.LoadFromFile(MainDirectory+'apikey.txt');
    apikey:=apifile[0];
    apifile.free;
  end;
  apikey:=InputBox('enter or change your api key','https://steamcommunity.com/dev/apikey',apikey);
  if apikey = '' then
    exit
  else
    begin
      apifile:=TStringList.Create;
      apifile.Add(apikey);
      apifile.SaveToFile('apikey.txt');
      apifile.free;
    end;
end;

procedure TFormMain.ButtonDirClick(Sender: TObject);
var
  replayfolder:TStringList;
  PathOut: string;
begin
  PathOut:=EditPath.Text;
  SelectDirectory('Select a directory',PathOut, PathOut);
  if Pathout <> '' then
    EditPath.Text:=PathOut;
  replayfolder:=TStringList.Create;
  replayfolder.Add(EditPath.Text);
  replayfolder.SaveToFile(MainDirectory+'replayfolder.txt');
  replayfolder.free;
end;

procedure TFormMain.AddPlayerToList(var PlayerURL,FileName:String;var demoDate:Integer);
var
  i:Integer;
  bCheck:Boolean;
begin
  bCheck:=False;
  for i := 0 to length(Playerlist)-1 do
    if Playerlist[i].SteamId = PlayerURL then
    begin
      bCheck := True;
      inc(Playerlist[i].playedMatches);
    end;
  if not bCheck then
  begin
    setlength(Playerlist,length(Playerlist)+1);
    Playerlist[length(Playerlist)-1].SteamId:=PlayerURL;
    Playerlist[length(Playerlist)-1].MatchName:=FileName;
    Playerlist[length(Playerlist)-1].demoDate:=demoDate;
  end;
end;

function TFormMain.Compare(i:Integer):Boolean;
const
  cByte: Array [0..23] of Byte = ($1A,$04,$08,$06,$38,$00,$1A,$04,$08,$04,$28,$00,$1A,$04,$08,$04,$28,$00,$1A,$04,$08,$04,$28,$00);
var
  j:Integer;
begin
  Result:=True;
  for j := 0 to 23 do
    if myArray[i+j]<>cByte[j] then
    begin
      Result:=False;
      Break;
    end;
end;

procedure TFormMain.FindID;
var
  i,j,k:Integer;
  s:String;
  idList:Array of String;
  bTest:Boolean;
begin
  k:=0;
  setlength(idList,0);
  for i := 0 to iFileSize-1000 do
    if Compare(i) then
    begin
      s:='';
      for j := -17 to -1 do
        s:=s+Char(MyArray[i+j]);
      bTest:=False;
      for j := 0 to length(idList)-1 do
        if k>0 then
          if idList[j]=s then
            bTest:=True;
      if (not bTest) and (s[1] = '7') then         //check 7 !
      begin
        inc(k);
        setlength(idList,k);
        idList[k-1]:=s;
      end;
    end;
    setlength(Server.Player,length(idList));
    for j := 0 to length(idList)-1 do
      Server.Player[j]:=idList[j];
end;

function TFormMain.GetArrayString(Index,Size:Integer):String;
var
  i:Integer;
begin
  Result:='';
  for i := 0 to Size-1 do
     Result:=Result+Char(MyArray[Index+i]);
end;

procedure TFormMain.GetPlayers(var Filepath,FileName:String);
var
  s:Single;
  count: Integer;
begin
    FileMode :=  fmShareDenyNone;
    AssignFile(myFile,Filepath+FileName);
    Reset(myFile, 1);
    iFileSize:=FileSize(myFile);
    setlength(myArray,iFileSize);
    count:=0;
    BlockRead(myFile, myArray[0], iFileSize, count);
    CloseFile(myFile);
    FindID;
    Server.Server:=GetArrayString(16,260-1);
    Server.Client:=GetArrayString(16+260,260);
    Server.ProtVer:=IntToStr(Integer(MyArray[8]));
    Server.NetVer:=IntToStr(Integer(MyArray[12]));
    Server.Map:=GetArrayString(16+260+260,260);
    s:=0;
    Move(MyArray[16+260+260+260+260],s,4);
    Server.Time:=FloatToStrF(s/60,ffFixed, 8, 2);
    setlength(myArray,0);
    Server.demoDate:=FileAge(Filepath+FileName) ;
end;

procedure getDemos(mydir:String;var Stringlist:TStringlist);
var
  searchResult : TSearchRec;
begin
  SetCurrentDir(mydir);
  if FindFirst('*.dem', faAnyFile, searchResult) = 0 then
  begin
    Stringlist.Add(searchResult.Name);
    while FindNext(searchResult) = 0 do
      Stringlist.Add(searchResult.Name);
  end;
end;

procedure TFormMain.ButtonListClick(Sender: TObject);
var
  Stringlist:TStringlist;
  i,j:Integer;
  stepsize,currstep:Double;
  sFileName,sPath:String;
  maxsteps:Integer;
begin
  //list demos
  Stringlist:=TStringList.Create;
  getDemos(EditPath.Text,Stringlist);
  ListBox.Items:=Stringlist;
  Stringlist.Free;
  //list players
  currstep:=0;
  maxsteps:=ListBox.Items.Count;
  if maxsteps>0 then
  begin
    stepsize:=100/maxsteps;
    for i := 0 to maxsteps-1 do
      begin
        sFileName:=ListBox.Items.Strings[i];
        if sFileName <> '' then
        begin
          LabelProgress.Caption:=IntToStr(i+1)+'/'+IntToStr(maxsteps)+' demos checked';
          currstep:=currstep+stepsize;
          ProgressBar.Position:=Round(currstep);
          Application.ProcessMessages;
          sPath:=EditPath.Text +'/' ;
          GetPlayers(sPath, sFileName);
          for j := 0 to length(Server.Player)-1 do
          AddPlayerToList(Server.Player[j],sFileName,Server.demoDate);
        end;
      end;
    {for i := 0 to length(Server.Player)-1 do
    begin
    end;    }
    LabelProgressPlayer.Caption:='0/'+IntToStr(length(Playerlist));
    ButtonCheckAndSort.Enabled:=True;
    ProgressBar.Position:=0;
  end;
end;

procedure TFormMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  replayfolder:TStringList;
begin
  replayfolder:=TStringList.Create;
  replayfolder.Add(EditPath.Text);
  replayfolder.SaveToFile(MainDirectory+'replayfolder.txt');
  replayfolder.free;
end;


end.

