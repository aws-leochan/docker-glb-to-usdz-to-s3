# docker-glb-to-usdz-to-s3
This Docker Container converts files stored on Amazon S3 from glb to usdz format.

*Note: This project is not officially supported by Amazon*
# Example usage:
```
 docker run -e INPUT_GLB_S3_FILEPATH='myS3Bucket/myS3Folder/myModel.glb' \
   -e OUTPUT_USDZ_FILE='myModel.usdz' \
   -e OUTPUT_S3_PATH='myS3Bucket/myS3Folder' \
   -e AWS_REGION='us-west-2' \
   -e AWS_ACCESS_KEY_ID='<your-access-key>' \
   -e AWS_SECRET_ACCESS_KEY='<your-secret-key>' \
   -it --rm awsleochan/docker-glb-to-usdz-to-s3
```
