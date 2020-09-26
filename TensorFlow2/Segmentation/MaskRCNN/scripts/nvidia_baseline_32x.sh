#!/usr/bin/env bash
# Copyright (c) 2020, NVIDIA CORPORATION. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source activate tensorflow2_latest_p37

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
rm -rf $BASEDIR/../results_32x
mkdir -p $BASEDIR/../results_32x
/opt/amazon/openmpi/bin/mpirun --allow-run-as-root --tag-output --mca plm_rsh_no_tree_spawn 1 \
    --mca btl_tcp_if_exclude lo,docker0 \
    --hostfile ~/hosts \
    -N 8 \
    -x NCCL_DEBUG=VERSION \
    -x LD_LIBRARY_PATH \
    -x PATH \
    --oversubscribe \
    /home/ubuntu/anaconda3/envs/tensorflow2_latest_p37/bin/python ${BASEDIR}/../mask_rcnn_main.py \
        --mode="train_and_eval" \
        --checkpoint="/home/ubuntu/DeepLearningExamples/TensorFlow2/Segmentation/MaskRCNN/resnet/resnet-nhwc-2018-02-07/model.ckpt-112603" \
        --eval_samples=5000 \
        --init_learning_rate=0.24 \
        --learning_rate_steps="5625,7500" \
        --optimizer_type="SGD" \
        --lr_schedule="piecewise" \
        --model_dir="$BASEDIR/../results_32x" \
        --num_steps_per_eval=462 \
        --warmup_learning_rate=0.000133 \
        --warmup_steps=1800 \
        --global_gradient_clip_ratio=0.0 \
        --total_steps=40000 \
        --l2_weight_decay=1e-4 \
        --train_batch_size=1 \
        --eval_batch_size=1 \
        --dist_eval \
        --training_file_pattern="/home/ubuntu/data/nv_coco/train*.tfrecord" \
        --validation_file_pattern="/home/ubuntu/data/nv_coco/val*.tfrecord" \
        --val_json_file="/home/ubuntu/data/annotations/instances_val2017.json" \
        --amp \
        --use_batched_nms \
        --xla \
        --use_custom_box_proposals_op | tee $BASEDIR/../results_32x/run_32x.log

