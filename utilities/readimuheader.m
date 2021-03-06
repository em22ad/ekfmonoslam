function [fimu, imudata, preimudata]=readimuheader(imufile, preimudata, startTime, Counter, imuFileType)
% input
% imuFileType
%   0: plain text 3dm gx3-35 data,
%   1: H764G 1 comprehensive csv
%   2: steval mki 062v2 from Yujia file
%   3: steval iNemo suite output data
%   4: microstrain csv
%   5: epson csv
% Counter is a struct that has at least one field numimurecords
% imufile: imu file name

% output:
% fimu the file pointer after opening the file
% imudata: the entry of imu data that has timestamp no less than startTime
% of format [time(sec), ax, ay, az(,/s^2), wx, wy, wz(rad/s)]
% preimudata: stores Counter.numimurecords inertial data that are just
% before the retrieved imu data

if(nargin<5)
    imuFileType=0;
end
switch( imuFileType)
    case 0% plain text 3dm gx3-35 data
        % make sure preimudata is transferred correctly, no memory leaking
        fimu=fopen(imufile,'r');
        fgetl(fimu);% remove the header
        hstream= fgetl(fimu);
        mass=textscan(hstream,'%f','delimiter',',');
        imudata=mass{1};
        while(imudata(7,1)==0||imudata(1,1)<startTime)
            preimudata.addLast(imudata(:,end));%record previous imudata
            if(preimudata.size()>Counter.numimurecords)
                preimudata.removeFirst();
            end
            hstream= fgetl(fimu);
            mass=textscan(hstream,'%f','delimiter',',');
            imudata=mass{1};
        end
    case 1 % H764G-1 comprehensive csv data
        %open files
        fimu=fopen(imufile,'r');
        h= fgetl(fimu);
        while(true)
            if(~isempty(strfind(h,'RAW 01')))
                break;
            else h= fgetl(fimu);
            end
        end
        h= fgetl(fimu);
        mass=textscan(h,'%f','delimiter',',');
        imudata=mass{1};
        while(imudata(9,1)==0||imudata(2,1)<startTime)
            imudata=imudata(2:8,1);% gps time, xyz delta v, xyz delta theta
            imudata(2:4,1)=imudata(2:4,1)*.3048;% convert to metric unit meter
            preimudata.addLast(imudata(:,end));%record previous imudata
            if(preimudata.size()>Counter.numimurecords)
                preimudata.removeFirst();
            end
            h= fgetl(fimu);
            mass=textscan(h,'%f','delimiter',',');
            imudata=mass{1};
        end
        imudata=imudata(2:8,1);% gps time, xyz delta v, xyz delta theta
        imudata(2:4,1)=imudata(2:4,1)*.3048;% convert to metric unit meter
    case 2 % steval mki 062v2 from Yujia file
        % make sure preimudata is transferred correctly, no memory leaking
        fimu=fopen(imufile,'r');
        hstream= fgetl(fimu);
        if(isempty(hstream))
            hstream= fgetl(fimu);
        end
        hstream=fgetl(fimu);% discard first two lines
        hstream=fgetl(fimu);
        mass=textscan(hstream,'%f','delimiter',' ');
        imudata=mass{1};
        hstream= fgetl(fimu);
        imu_scalefactor = 9.78;
        while(imudata(1,1)<startTime)
            imudata(2:4,1) = imudata(2:4,1)/1000.0 * imu_scalefactor;
            imudata(5:7,1) = imudata(5:7,1)*pi/180;
            imudata(6,1) = -imudata(6,1); % wrong data format
            preimudata.addLast(imudata(:,end));%record previous imudata
            if(preimudata.size()>Counter.numimurecords)
                preimudata.removeFirst();
            end
            hstream= fgetl(fimu);
            mass=textscan(hstream,'%f','delimiter',' ');
            imudata=mass{1};
            hstream= fgetl(fimu);
        end
        imudata(2:4,1) = imudata(2:4,1)/1000.0 * imu_scalefactor;
        imudata(5:7,1) = imudata(5:7,1)*pi/180;
        imudata(6,1) = -imudata(6,1);
    case 3 % steval iNemo suite output data
        fimu=fopen(imufile,'r');
        fgetl(fimu); % discard first line
        hstream=fgetl(fimu);
        mass=textscan(hstream,'%f','delimiter',',');
        imudata=mass{1};
        imudata(1)=imudata(1)/1000;
        imu_scalefactor = 9.8;
        while(imudata(1,1)<startTime)
            imudata(2:4,1) = imudata(2:4,1)/1000.0 * imu_scalefactor;
            imudata(5:7,1) = imudata(5:7,1)*pi/180;
            imudata(6,1) = -imudata(6,1); % wrong data format
            preimudata.addLast(imudata(:,end));%record previous imudata
            if(preimudata.size()>Counter.numimurecords)
                preimudata.removeFirst();
            end
            hstream= fgetl(fimu);
            mass=textscan(hstream,'%f','delimiter',',');
            imudata=mass{1};
            imudata(1)=imudata(1)/1000;
        end
        imudata(2:4,1) = imudata(2:4,1)/1000.0 * imu_scalefactor;
        imudata(5:7,1) = imudata(5:7,1)*pi/180;
        imudata(6,1) = -imudata(6,1);
    case 4 % microstrain csv data
        fimu=fopen(imufile,'r');
        % remove first 16 lines
        headerLines=16;
        for i=1:headerLines
            fgetl(fimu); % discard first lines
        end
        hstream=fgetl(fimu);
        mass=textscan(hstream,'%f','delimiter',',');
        imudata=mass{1};
        imudata=imudata([3,8:13]);
        
        while(imudata(1)<startTime || sum(isnan(imudata)))
            if(~sum(isnan(imudata)))
                imudata(2:4)=imudata(2:4)*9.80665;
                preimudata.addLast(imudata(:,end));%record previous imudata
                if(preimudata.size()>Counter.numimurecords)
                    preimudata.removeFirst();
                end
            end
            hstream=fgetl(fimu);
            if (~ischar(hstream))
                imudata=[];
                return;
            end
            mass=textscan(hstream,'%f','delimiter',',');
            imudata=mass{1};
            imudata=imudata([3,8:13]);
        end
        imudata(2:4)=imudata(2:4)*9.80665;
    case 5 % read the header of epson csv data
        fimu=fopen(imufile,'r');
        % remove first 4 lines
        headerLines=4;
        for i=1:headerLines
            fgetl(fimu); % discard header
        end
        hstream=fgetl(fimu);
        mass=textscan(hstream,'%f','delimiter',',');
        imudata=mass{1};
        imudata=imudata([2,[8:10, 5:7]]);
        while(imudata(1)<startTime)
            imudata(2:4)=imudata(2:4)*9.8/1000;
            imudata(5:7)=imudata(5:7)*pi/180;
            preimudata.addLast(imudata(:,end));%record previous imudata
            if(preimudata.size()>Counter.numimurecords)
                preimudata.removeFirst();
            end
            hstream=fgetl(fimu);
            if (~ischar(hstream))
                imudata=[];
                return;
            end
            mass=textscan(hstream,'%f','delimiter',',');
            imudata=mass{1};
            imudata=imudata([2,[8:10, 5:7]]);
        end
        imudata(2:4)=imudata(2:4)*9.80665/1000;
        imudata(5:7)=imudata(5:7)*pi/180;
end
