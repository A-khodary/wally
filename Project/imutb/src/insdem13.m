%
%   insdem13.m
%      Constant-altitude, constant velocity user
%      Spheroidal, rotating earth effects (and gravity) included

clear
dph2rps = (pi/180)/3600;   % conversion constant from deg/hr to rad/sec

tru_height = 10000;     % altitude is 10 km
totvelnmph = 500;   % total velocity in knots (nautical miles per hour)
totvelnmps = totvelnmph/3600;   % total velocity in nautical miles per second
totvelmps = totvelnmph*1.6878*0.3048;
earthflg = 1;

JFK_deg = [40+38/60 -(73+47/60)];  % New York (JFK airport)
JFK_rad = JFK_deg*pi/180;
IST_deg = [40.983 28.817];         % Istanbul
IST_rad = IST_deg*pi/180;

fprintf(1,' Generating Great Circle Route \n')

latlonstart = [JFK_rad(1) JFK_rad(2)];
latlonend = [IST_rad(1) IST_rad(2)];
[lat_prof,lon_prof,tc_prof,totdist] = ...
   greatcir(latlonstart,latlonend,tru_height,0,2);

npts = max(size(lat_prof));
tot_time = totdist/totvelnmps;             % total flight time in seconds
time = (0:npts-1)*(tot_time/(npts-1));       % time vector
totvel_prof = totvelnmph*ones(1,npts);
height_prof = tru_height*ones(1,npts);

fprintf(1,' . . . . . . . . . \n')
fprintf(1,'Total Distance = %i nautical miles \n',round(totdist))
fprintf(1,' . . . . . . . . . \n')
fprintf(1,'Number of Waypoints: %i \n',npts)
fprintf(1,' . . . . . . . . . \n')
fprintf(1,' Generating Flight Profile Parameters \n')

DCMnb_prof = dcmnbgen(tc_prof);

dthetbody = gendthet(DCMnb_prof);       % component of delta-theta associated
%                                      % with body motion

DCMel_prof = dcmelgen(lat_prof, lon_prof, tc_prof);

deltaer = earthrot(time,DCMel_prof,DCMnb_prof);   % component of delta-theta
%                                                 % associated with earth-rate

%                                    % generate the component of delta-theta
%                                    % associated with craft rate
deltacr = gendelcr(lat_prof,tc_prof,totvel_prof,...
   height_prof,time,DCMnb_prof,DCMel_prof,earthflg);

deltheta = dthetbody + deltaer + deltacr;   % ideal (error-free) gyro output

dtherr = zeros(size(deltheta));        % no delta-theta errors for this demo

est_dtheta = deltheta + dtherr;   % form profiles of 'measured' delta-theta's

roll(1) = 0;                 % Aircraft is nominally level for the entire
pitch(1) = 0;                % flight path.  Note that craft rate was
%                            % handled earlier.

yaw(1) = tc_prof(1);       % Wind is NOT modeled so true yaw = true course

laterr=0;  longerr=0;  alphaerr=0;        % INITIALIZATION in this whole section
height = tru_height; height_err = 0;
height1 = tru_height;  height2 = tru_height;
est_lat(1) = lat_prof(1); est_lat(2) = lat_prof(1);
est_lon(1) = lon_prof(1);
vx1 = totvelmps*sin(tc_prof(1)); vx2 = vx1;
vy1 = totvelmps*cos(tc_prof(1)); vy2 = vy1;
vel_l(1,:) = [vx2 vy2 0];
vel2 = [vx1 vy1 0];  vel1 = vel2;
lat2 = lat_prof(1);  lat1 = lat_prof(1) - (lat_prof(2)-lat_prof(1));
DCMnb = [DCMnb_prof(1,1:3); DCMnb_prof(1,4:6); DCMnb_prof(1,7:9)];
est_DCMbn = DCMnb';
est_DCMel = [DCMel_prof(1,1:3); DCMel_prof(1,4:6); DCMel_prof(1,7:9)];
vertmech = 0;
omega2_el_L = crafrate(lat_prof(1),vx1,vy1,height_prof(1),est_DCMel,earthflg,vertmech);

vel_prof_L = genvelpr(tc_prof,totvel_prof);   % Generate velocity profile

deltav_b = gendv(vel_prof_L,DCMnb_prof);    % Generate the component of delta-V
%                                           % associated with body motion relative
%                                           % to the earth

%                                           % Generate the Coriolis component
%                                           % of delta-V
dvcor = gendvcor(lat_prof,totvel_prof,tc_prof,height_prof,time,...
   DCMnb_prof,DCMel_prof,earthflg);

dvtot = deltav_b + dvcor;

dverr = zeros(size(dvtot));                  % No errors for this demo

est_dv = dvtot + dverr;           % form profile of 'measured' delta-V's

fprintf(1,' . . . . . . . . . \n')
fprintf(1,' Starting nav computations \n')
C = [0 1 0; 1 0 0; 0 0 -1];    % conversion between NED and ENU

for i = 2:npts-1,
   td12 = time(i) - time(i-1);
   tdex = 0.5*td12;
   tdint = time(i) - time(i-1);
   
   est_DCMbn = bodupdat(est_DCMbn,est_dtheta(i,1:3));
   
   [DCM_ll_I, omega_el_L, omega_ie_L] = lclevupd(lat1,lat2,vx1,vx2,vy1,vy2,...
      height1,height2,td12,tdex,tdint,est_DCMel,vertmech,1,earthflg);
   
   est_DCMbn = C*(DCM_ll_I*(C*est_DCMbn));
   
   eul_vect = dcm2eulr(est_DCMbn);
   roll(i) = eul_vect(1);
   pitch(i) = eul_vect(2);
   yaw(i) = eul_vect(3);
   
   est_delv_b = est_dv(i,1:3);       % extract delta-V for current point in time
          
   del_Vl = C*(est_DCMbn*est_delv_b');

   omega1_el_L = omega2_el_L;   omega2_el_L = omega_el_L;
   [est_DCMel, DCM_ll_E] = navupdat(omega1_el_L,omega2_el_L,td12,est_DCMel,1);
   
   h_extr = extrapol(height1,height2,td12,tdex);
   lat_extr = extrapol(lat1,lat2,td12,tdex);
   g_extr = gravity(lat_extr,h_extr);
 
   vtmp = velupdat(vel2,vel1,td12,tdex,del_Vl,...
      omega_el_L,est_DCMel,g_extr,0,tdint);
   
   vel_l(i,:) = vtmp';
   
   est_height(i,1) = tru_height;
   height1 = height2;  height2 = est_height(i,1);
    vx1 = vx2; vy1 = vy2;
    vx2 = vel_l(i,1);  vy2 = vel_l(i,2);
    vel1 = vel2;   vel2 = vel_l(i,:);
    llw_vect = dcm2llw(est_DCMel);
    est_lat(i) = llw_vect(1); est_lon(i) = llw_vect(2);  est_alpha(i) = llw_vect(3);
    lat1 = lat2;  lat2 = est_lat(i);
    laterr(i) = est_lat(i) - lat_prof(i);
    longerr(i) = est_lon(i) - lon_prof(i);
end

close
t = time(2:npts);
subplot(211)
plot(t/3600,lat_prof(2:npts)*180/pi,t/3600,est_lat*180/pi)
title('New York to Istanbul')
ylabel('latitude in degrees')
xlabel('time in hours')
text(2,45,'Note that in both plots the true and')
text(2,43,'computed routes overlay each other')

subplot(212)
plot(t/3600,lon_prof(2:npts)*180/pi,t/3600,est_lon*180/pi)
ylabel('longitude in degrees')
xlabel('time in hours')
%%print -dbitmap dem13
