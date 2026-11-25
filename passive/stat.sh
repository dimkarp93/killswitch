#!/bin/bash
sudo nft list chain inet killswitch mark_output
sudo nft list chain inet killswitch guard_output

## Expected
# В mark_output должны увеличиваться счётчики при обращении к защищённым адресам.
# В guard_output счётчики drop должны увеличиваться только при попытке отправить защищённый трафик не через amn0.