rm -rf ~/snabb/src/UONetflowSnabb
rm -rf ~/snabb/src/obj/program/UONetflowSnabb
rm ~/snabb/src/snabb
cp -r ~/UONetflowSnabb ~/snabb/src/program
make -j -C ~/snabb
