function enable_teensy(state)
if (nargin < 1) | (isempty(state))
    state = 1;
end

pkg load instrument-control
ser = serial('/dev/ttyACM0');

if state == 1
    srl_write(ser, 'e');
    disp('Enabled teensy');
else
    srl_write(ser, 'd');
    disp('Disabled teensy');
end

