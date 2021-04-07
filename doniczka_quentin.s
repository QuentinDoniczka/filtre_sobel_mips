.data
demande_fichier:	.asciiz "saisissez le nom de votre fichier sans l'extention: "
bmp:			.asciiz ".bmp"
bmp_res:		.asciiz "Contour.bmp"
buffer:			.space 6        # On initialise un buffer de taille 6
buffer_fichier:		.space 64
buffer_fichier_concat:	.space 128
	.text
	.globl main
main:
    
    	la $a0 demande_fichier          # Envoie du texte et des instruction dans la console
    	li $v0 4                        
    	syscall                         

    	la $a0 buffer_fichier           # On stock le resulat de l'utilisateur
    	li $a1 64                     
    	li $v0 8                        
    	syscall
    	move $s7 $a0

retire_entrer_sentinelle:
    	lb $t0 0($s7)                    # on verifi pour chaque caractere si il sagie de la sentinelle ou d'entrer
    	beq $t0 0 end_retire_sent
    	beq $t0 10 end_retire_sent     
    	addi $s7 $s7 1                   
   	 j retire_entrer_sentinelle
end_retire_sent:
    	li $t1 0
    	sb $t1 0($s7)                    # On place la nouvelle sentinelle

    	la $a0 buffer_fichier
    	la $a1 bmp
    	la $a2 buffer_fichier_concat
    	jal concatener
    	

	la $a0 buffer_fichier_concat    # Nom du fichier
	la $a1 buffer			# buffer de taille 6
	jal copie_fichier
	move $s0 $v0			# Adresse du tableau
	move $a0 $s0
	jal Filtre_sobel
	move $s1 $v0
	
	la $a0 buffer_fichier
    	la $a1 bmp_res
    	la $a2 buffer_fichier_concat
    	jal concatener
	move $a0 $s1			# Adresse du tableau
	la $a1 buffer_fichier_concat
	jal ecrit_bmp
	j end
	
# Concatene 2 chaine de caractere dans une 3eme
## Entrer: $a0 = adresse de la 1ere chaine
##         $a1 = adresse de la 2eme chaine
##	   $a3 = adresse contenant la concatenation des deux 1er
concatener:

    	# prologue
    	subu $sp $sp 12
    	sw $s2 8($sp)
    	sw $s1 4($sp)
    	sw $s0 0($sp)

   	move $s0 $a0                        
    	move $s1 $a1                        
    	move $s2 $a2


boucle_chaine1:
    	lb $t0 0($s0)                       # On stock 1 par 1 les char dans le string
    	sb $t0 0($s2)
    	beq $t0 0 boucle_chaine2    	    # On passe a la copie de la 2eme quand la 1ere est terminer
    	addi $s0 $s0 1                      
    	addi $s2 $s2 1                      
    	j boucle_chaine1

    	
boucle_chaine2:
    	lb $t0 0($s1)                       # On stock 1 par 1 les char dans le string
    	beq $t0 0 end_chaine      	    # fin si tout est copier
    	sb $t0 0($s2)                       
    	addi $s1 $s1 1                      
    	addi $s2 $s2 1                      

    	j boucle_chaine2
end_chaine:
    	# epilogue
    	lw $s2 8($sp)
    	lw $s1 4($sp)
    	lw $s0 0($sp)
    	addu $sp $sp 12

    	jr $ra
 
# Copie la totalité du fichier et renvoie l'adresse du tableau copier
## preconditon: buffer de taille 6 minimum
## Entrer: $a0 = adresse du nom du fichier
##	   $a1 = buffer
## Sortie: $v0 = Adresse de la copie
copie_fichier:
	# prologue
	subu $sp $sp 28
   	sw $s5 24($sp)
   	sw $s4 20($sp)
   	sw $s3 16($sp)
   	sw $s2 12($sp)
   	sw $s1 8($sp)
   	sw $s0 4($sp)
   	sw $ra 0($sp)
   	
   	move $s0 $a1			# adresse du buffer
   	move $s1 $a0			# Nom du fichier
   	
   	move $a0 $s1			# Nom du fichier
	jal open_bmp
	move $s2 $v0			# Description du fichier
	
	move $a0 $s2			# Description du fichier
	move $a1 $s0			# adresse du buffer
	li $a2 6			# on va chercher la taille du fichier
	li $v0 14
	syscall
	lh $t0 4($s0)
	sll $t1 $t0 16			# on deplace de 2 octet pour reconstuire la donner " taille du fichier en otctet"
	lh $t0 2($s0)
	add $s3 $t1 $t0			# taille de notre fichier en octet
	
	move $a0 $s3			# on crée un tableau de taille " taille en onctet du fichier"
	li $v0 9
	syscall
	move $s4 $v0			# Place l'adresse de notre tableau cree 
	li $s5 0			# Compteur position tableau
	li $t1 0			# Adresse tempon
	
copie_6:
	bge $s5 6 end_copie_6
	add $t1 $s0 $s5
	lb $t2 0($t1)
	add $t1 $s4 $s5
	sb $t2 0($t1)
	addi $s5 $s5 1
	j copie_6
end_copie_6:
	move $a0 $s2			# Description du fichier
	add $a1 $s4 $s5			# adresse du reste de la copie
	subi $a2 $s3 6			# on copie le reste du fichier
	li $v0 14
	syscall
	move $a0 $s2
	jal close_bmp
	
	move $v0 $s4
	#epilogue
    	lw $s5 24($sp)
    	lw $s4 20($sp)
    	lw $s3 16($sp)
    	lw $s2 12($sp)
   	lw $s1 8($sp)
   	lw $s0 4($sp)
    	lw $ra 0($sp)
    	addu $sp $sp 28
	jr $ra
	
# Ouvre un fichier et renvoi sa description
## Le programme s'arret si le fichier n'existe pas
## Entrer: $a0 = adresse du nom du fichier
## Sortie: $v0 = description du fichier
open_bmp:
					# $a0 adresse du nom du fichier
   	li $a1 0           		# lecture
    	li $a2 0          		# aucun mode
    	li $v0 13          		# ouverture du fichier
   	syscall
   	blt $v0 $zero open_bmp_null     # On quite si le fichier n'existe pas
	jr $ra				# $v0 descritption du fichier
 open_bmp_null:
	li $v0 10	 		# sortie de programme                         # A AMELIORER
	syscall
	
# Fermeture de la lecture d'un fichier
## Entrer: $a0 = description du fichier
## Sortie: NULL
close_bmp:
	li $v0 16          	 	# Fermeture du fichier
    	syscall
	jr $ra

# Recupere l'adresse de l'image
## preconditon:
## Entrer: $a0 = Adresse de notre tableau ou le fichier est stocker 
##	   
## Sortie: $v0 = Adresse du début de l'image
adresse_image:
	lh $t0 12($a0)			
	sll $t0 $t0 16			# decalage de 16 bit
	lh $t1 10($a0)			
	add $t2 $t0 $t1			# reconstruction des 4 octet
	add $v0 $a0 $t2			# On recupere l'adresse du premier element
	jr $ra
	
# Ouvre un fichier et renvoi sa description
## Le programme s'arret si le fichier n'existe pas
## Entrer: $a0 = adresse du nom du fichier
## Sortie: $v0 = description du fichier
creat_bmp:
					# $a0 adresse du nom du fichier
   	li $a1 1           		# lecture
    	li $a2 0          		# aucun mode
    	li $v0 13          		# ouverture du fichier
   	syscall
   	blt $v0 $zero creat_bmp_null     # On quite si le fichier n'existe pas
	jr $ra				# $v0 descritption du fichier
 creat_bmp_null:
	li $v0 10	 		# sortie de programme                         # A AMELIORER
	syscall

# Aplique le Filtre sobel et renvois le resultat dans un nouveau fichier
## preconditon:
## Entrer: $a0 = Adresse du tableau contenant le fichier
##
## Sortie: $v0 = Adresse du tableau après apllication du filtre
Filtre_sobel:
	#prologue
   	subu $sp $sp 28
   	sw $s5 24($sp)
   	sw $s4 20($sp)
   	sw $s3 16($sp)
   	sw $s2 12($sp)
   	sw $s1 8($sp)
   	sw $s0 4($sp)
   	sw $ra 0($sp)
   	
   	move $s0 $a0			# Adresse du tableau
	jal bmp_clean
	move $s1 $v0 			# Adresse du tableau resulat
	move $a0 $s0
	jal adresse_image
	move $s2 $v0			# adresse du debut de l'image de depart
	move $a0 $s1
	jal adresse_image
	move $s3 $v0			# adresse du debut de l'image resultat
	li $t0 0
	move $a0 $s0
	jal hauteur_bmp
	move $s4 $v0			# hauteur image
	sub $s4 $s4 1			# on travailera sans les bord
	move $a0 $s0
	jal largeur_bmp
	move $s5 $v0			# largeur image
	sub $s5 $s5 1			# on travailera sans les bord
	li $t0 1			# compteur hauteur
	li $t1 1			# compteur largeur
	li $t2 0			# adresse tempon lecture
	li $t3 0			# adresse tempon ecriture
	li $t4 0			# valeur calcule
	li $t5 0			# valeur a placer masques 1
	li $t6 0			# valeur a plcer masques 2
	li $t7 0			# valeur finale
b_f_sobel_hauteur:
	li $t1 1			# reset le compteur
	beq $t0 $s4 end_b_f_sobel_hauteur
b_f_sobel_largeur:
	beq $t1 $s5 end_b_f_sobel_largeur
	li $t5 0			# valeur a placer masques 1
	li $t6 0			# valeur a plcer masques 2
	mul $t2 $t0 256
	add $t2 $t2 $t1
	move $t3 $t2
	add $t2 $t2 $s2			# Adresse image de depart
	add $t3 $t3 $s3			# Adresse image finale
	
	# haut
	lb $t4 256($t2)
	mul $t4 $t4 -2
	add $t6 $t6 $t4			# masques 2
	lb $t4 255($t2)
	add $t5 $t5 $t4			# masques 1
	sub $t6 $t6 $t4			# masques 2
	lb $t4 257($t2)
	sub $t5 $t5 $t4			# masques 1
	sub $t6 $t6 $t4			# masques 2
	
	# milieu
	lb $t4 -1($t2)
	mul $t4 $t4 2
	add $t5 $t5 $t4			# masques 1
	lb $t4 1($t2)
	mul $t4 $t4 -2
	add $t5 $t5 $t4			# masques 1
	
	# bas
	lb $t4 -256($t2)
	mul $t4 $t4 2
	add $t6 $t6 $t4			# masques 2
	lb $t4 -257($t2)
	add $t5 $t5 $t4			# masques 1
	add $t6 $t6 $t4			# masques 2
	lb $t4 -255($t2)
	sub $t5 $t5 $t4			# masques 1
	add $t6 $t6 $t4			# masques 2
	
	abs $t5 $t5
	abs $t6 $t6
	add $t7 $t5 $t6
	bgt $t7 300 bruit
	j no_bruit
bruit:	
	li $t7 0
	j end_max_min
no_bruit:
	bgt $t7 180 max
	j no_max
max:	
	li $t7 255
	j end_max_min
no_max:
	ble $t7 150 min
	j end_max_min
min:		
	li $t7 0

end_max_min:
	sb $t7 0($t3)
	addi $t1 $t1 1
	j b_f_sobel_largeur
	
end_b_f_sobel_largeur:
	addi $t0 $t0 1
	j b_f_sobel_hauteur
end_b_f_sobel_hauteur:
	move $v0 $s1
   	#epilogue
   	lw $s5 24($sp)
   	lw $s4 20($sp)
   	lw $s3 16($sp)
   	lw $s2 12($sp)
   	lw $s1 8($sp)
   	lw $s0 4($sp)
   	lw $ra 0($sp)
    	addu $sp $sp 28
	jr $ra

# affiche pour debugger
## preconditon:
## Entrer: $a0 = nombre a afficher en exa
##	   
## Sortie:
debug:
	#prologue
	subu $sp $sp 4
	sw $v0 0($sp)
    	
	li $v0 34
	syscall
	li $a0 3000			# en ms ( donc 1 sec la)
	li $v0 32
	syscall
	
	#epilogue
	lw $v0 0($sp)
    	addu $sp $sp 4
	jr $ra
# Ecrit ou crée un fichier bmp avec le tableau bmp
## preconditon:
## Entrer: $a0 = Adresse du tableau contenant le fichier a ecrire
##	   $a1 = Adresse du nom du fichier
## Sortie: $v0 = NULL
ecrit_bmp:
	#prologue
	subu $sp $sp 4
	sw $ra 0($sp)
	move $s0 $a0			# Adresse du tableau contenant le fichier a ecrire
	move $s1 $a1			# Adresse du nom du fichier

   	move $a0 $s1			# Adresse du nom du fichier			
    	jal creat_bmp
    	move $s2 $v0			# description du fichier
    	
    	lh $t0 4($s0)
	sll $t1 $t0 16			# on deplace de 2 octet pour reconstuire la donner " taille du fichier en otctet"
	lh $t0 2($s0)
	add $s3 $t1 $t0			# taille de notre fichier en octet
	
	move $a0 $s2			# description du fichier
	move $a1 $s0 			# Address of output buffer
	move $a2 $s3			# Number of characters to write
	li $v0 15
	syscall
	move $a0 $s2
	jal close_bmp
	#epilogue
	lw $ra 0($sp)
    	addu $sp $sp 4
	jr $ra
	
# prend un fichier bmp en entrer et renvoi l'adresse de se fichier avec l'image noir
## preconditon:
## Entrer: $a0 = Adresse du tableau contenant le fichier
##
## Sortie: $v0 = Adresse du nouveau tableau
bmp_clean:
	#prologue
   	subu $sp $sp 20
   	sw $s3 16($sp)
   	sw $s2 12($sp)
   	sw $s1 8($sp)
   	sw $s0 4($sp)
   	sw $ra 0($sp)
   	
   	move $s0 $a0			# adresse du tableau
	lh $t0 4($s0)
	sll $t1 $t0 16			# on deplace de 2 octet pour reconstuire la donner " taille du fichier en otctet"
	lh $t0 2($s0)
	add $s1 $t1 $t0			# taille de notre fichier en octet
	move $a0 $s1			# on crée un tableau de taille " taille en octet du fichier"
	li $v0 9
	syscall
	move $s2 $v0			# adresse du nouveau tableau
	lh $t0 12($s0)			
	sll $t0 $t0 16			# decalage de 16 bit
	lh $t1 10($s0)			
	add $t9 $t0 $t1			# reconstruction des 4 octet
	li $t0 0			# compteur bit acutel fichier
	li $t1 0			# adresse tempon fichier in
	li $t2 0			# adresse tempon fichier out
b_post_image:
	bge $t0 $t9 end_b_post_image
	add $t1 $s0 $t0
	lb $t3 0($t1)
	add $t2 $s2 $t0
	sb $t3 0($t2)
	addi $t0 $t0 1
	j b_post_image
end_b_post_image:
	move $v0 $s2
   	#epilogue
   	lw $s3 16($sp)
   	lw $s2 12($sp)
   	lw $s1 8($sp)
   	lw $s0 4($sp)
   	lw $ra 0($sp)
    	addu $sp $sp 20
	jr $ra
# recupere la largeur
## preconditon:
## Entrer: $a0 = Adresse du tableau contenant le fichier
##
## Sortie: $v0 = valeur de la largeur de l'image
largeur_bmp:
	lh $t0 20($a0)			
	sll $t0 $t0 16			# decalage de 16 bit
	lh $t1 18($a0)
	add $v0 $t1 $t0
	jr $ra
	
	
# recupere la hauteur
## preconditon:
## Entrer: $a0 = Adresse du tableau contenant le fichier
##
## Sortie: $v0 = valeur de la hauteur de l'image
hauteur_bmp:
	lh $t0 24($a0)			
	sll $t0 $t0 16			# decalage de 16 bit
	lh $t1 22($a0)	
	add $v0 $t1 $t0	
	jr $ra

end:
	li $v0 10	 		# sortie de programme
	syscall
