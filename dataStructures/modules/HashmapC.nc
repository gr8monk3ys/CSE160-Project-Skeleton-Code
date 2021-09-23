/**
 * ANDES Lab - University of California, Merced
 * This moudle provides a simple hashmap.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include "../../includes/channels.h"
generic module HashmapC(typedef t, int n){
   provides interface Hashmap<t>;
}

implementation{
   uint16_t HASH_MAX_SIZE = n;

   // This index is reserved for empty values.
   uint16_t EMPTY_KEY = 0;

   typedef struct hashmapEntry{
      uint32_t key;
      t value;
   }hashmapEntry;

   hashmapEntry map[n];
   uint32_t keys[n];
   uint16_t numofVals;

   // Hashing Functions
   uint32_t hash2(uint32_t k){
      return k%13;
   }
   uint32_t hash3(uint32_t k){
      return 1+k%11;
   }

   uint32_t hash(uint32_t k, uint32_t i){
      return (hash2(k)+ i*hash3(k))%HASH_MAX_SIZE;
   }

   command void Hashmap.insert(uint32_t k, t input){
      uint32_t i=0;	uint32_t j=0;

      if(k == EMPTY_KEY){
          dbg(HASHMAP_CHANNEL, "[HASHMAP] You cannot insert a key of %d.", EMPTY_KEY);
          return;
      }

      do{
         // Generate a hash.
         j=hash(k, i);

         // Check to see if the key is free or if we already have a value located here.
         if(map[j].key==EMPTY_KEY || map[j].key==k){
             // If the key is empty, we can add it to the list of keys and increment
             // the total number of values we have..
            if(map[j].key==EMPTY_KEY){
               keys[numofVals]=k;
               numofVals++;
            }

            // Assign key and input.
            map[j].value=input;
            map[j].key = k;
            return;
         }
         i++;
      // This will allow a total of HASH_MAX_SIZE misses. It can be greater,
      // BUt it is unlikely to occur.
      }while(i<HASH_MAX_SIZE);
   }


	// We keep an internal list of all the keys we have. This is meant to remove it
   // from that internal list.
   void removeFromKeyList(uint32_t k){
      int i;
      int j;
      dbg(HASHMAP_CHANNEL, "Removing entry %d\n", k);
      for(i=0; i<numofVals; i++){
          // Once we find the key we are looking for, we can begin the process of
          // shifting all the values to the left. e.g. [1, 2, 3, 4, 0] key = 2
          // the new internal list would be [1, 3, 4, 0, 0];
         if(keys[i]==k){
            dbg(HASHMAP_CHANNEL, "Key found at %d\n", i);

            // Shift everything to the left.
            for(j=i; j<HASH_MAX_SIZE; j++){
                // Stop if we hit a EMPTY_KEY POSITION.
               if(keys[j]==EMPTY_KEY)break;
               dbg(HASHMAP_CHANNEL, "Moving %d to %d\n", j, j+1);
               dbg(HASHMAP_CHANNEL, "Replacing %d with %d\n", keys[j], keys[j+1]);
               keys[j]=keys[j+1];
            }

            // Set the last key to be empty or there will be a repeat of the
            // last value.
            keys[numofVals] = EMPTY_KEY;

            numofVals--;
            dbg("hashmap", "Done removing entry\n");
            return;
         }
      }

   }


   command void Hashmap.remove(uint32_t k){
      uint32_t i=0;	uint32_t j=0;
      bool removed = 0;
      do{
         j=hash(k, i);
         if(map[j].key == k){
            map[j].key=0;
            removed = 1;
            break;
         }
         i++;
      }while(i<HASH_MAX_SIZE);
      if(removed)
	{
		removeFromKeyList(k);
	}


   }

   
   command t Hashmap.get(uint32_t k){
      uint32_t i=0;	uint32_t j=0;
      do{
         j=hash(k, i);
         if(map[j].key == k)
            return map[j].value;
         i++;
      }while(i<HASH_MAX_SIZE);

      // We have to return something so we return the first key
      return map[0].value;
   }

   command bool Hashmap.contains(uint32_t k){
      uint32_t i=0;	uint32_t j=0;
      /*
      if(k == EMPTY_KEY)
	{
		return FALSE;
	}
	*/
      do{
         j=hash(k, i);
         if(map[j].key == k)
            return TRUE;
         i++;
      }while(i<HASH_MAX_SIZE);
      return FALSE;
   }

   command bool Hashmap.isEmpty(){
      if(numofVals==0)
         return TRUE;
      return FALSE;
   }

   command uint32_t* Hashmap.getKeys(){
      return keys;
   }

   command uint16_t Hashmap.size(){
      return numofVals;
   }
}
